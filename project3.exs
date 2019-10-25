defmodule DyServer do
  use DynamicSupervisor

  def start_link(init_arg) do
    {:ok, _pid} = DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def start_child(neighbors, hash_id, obj_lst, obj_lnk, max_hop) do
    child_spec =
      Supervisor.child_spec({Nodes, [neighbors, hash_id, obj_lst, obj_lnk, max_hop]},
        id: hash_id,
        restart: :temporary
      )

    IO.puts("Got the  child_spec")
    {:ok, child} = DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  def init(init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end

defmodule Nodes do
  use GenServer

  def start_link([neighbors, hash_id, obj_lst, obj_lnk, max_hop]) do
    id = hash_id

    {:ok, _pid} =
      GenServer.start_link(__MODULE__, {neighbors, hash_id, obj_lst, obj_lnk, max_hop},
        name: :"#{id}"
      )

    #  IO.puts("GenServer started")
  end

  def init({neighbors, hash_id, obj_lst, obj_lnk, max_hop}) do
    # CALL Find Neighbors here
    neighbors = Find_Neighbors.make_neighbors(hash_id)
    {:ok, {neighbors, hash_id, obj_lst, obj_lnk, max_hop}}
  end

  def handle_call({:request, hops}, _from, {neighbors, hash_id, obj_lst, obj_lnk, max_hop}) do
    # Change the state of max hops
    IO.puts("My no. of hops is #{hops}")
    {:reply, :ok, {neighbors, hash_id, obj_lst, obj_lnk, max_hop}}
  end

  def handle_call({:remove_me, id}, _from, {neighbors, hash_id, obj_lst, obj_lnk, max_hop}) do
    # Remove the given ID from the list
    {:reply, :ok, {neighbors, hash_id, obj_lst, obj_lnk, max_hop}}
  end

  def handle_call({:object_add, id}, _from, {neighbors, hash_id, obj_lst, obj_lnk, max_hop}) do
    obj_lst = obj_lst ++ [id]
    {:reply, :ok, {neighbors, hash_id, obj_lst, obj_lnk, max_hop}}
  end

  def handle_call(
        {:obj_lnk_add, obj_id, server_id},
        _from,
        {neighbors, hash_id, obj_lst, obj_lnk, max_hop}
      ) do
    obj_lnk = Map.put_new(obj_lnk, obj_id, server_id)
    {:reply, :ok, {neighbors, hash_id, obj_lst, obj_lnk, max_hop}}
  end
end

defmodule Other_jobs do
  def get_random_id(node, node_ids) do
    send_to = Enum.random(node_ids)
    # pid = :"#{send_to}"

    if send_to == node do
      get_random_id(node, node_ids)
    else
      send_to = send_to
    end
  end

  def start_children(last, x, node_ids) when x == last do
    hash_id = Integer.to_string(:rand.uniform(9999), 16)
    IO.puts("The hash_id is #{hash_id}")
    neighbors = %{}
    obj_lst = []
    obj_lnk = %{}
    DyServer.start_child(neighbors, hash_id, obj_lst, obj_lnk, max_hop)
    IO.puts("ALL children started")
    node_ids = node_ids ++ [hash_id]
  end

  def start_children(last, x, node_ids) do
    # new_id = :rand.uniform(10000)
    # sha = :crypto.hash(:sha, "#{new_id}")
    # TODO - Better way or shorter key
    # hash_id = sha |> Base.encode16()
    hash_id = Integer.to_string(:rand.uniform(9999), 16)
    IO.puts("The hash_id is #{hash_id}")
    node_ids = node_ids ++ [hash_id]
    IO.inspect(node_ids)
    # Maybe change later
    # max_hop = Enum.at(node_ids, 0)
    neighbors = %{}
    obj_lst = []
    obj_lnk = %{}
    DyServer.start_child(neighbors, hash_id, obj_lst, obj_lnk, max_hop)
    x = x + 1
    start_children(last, x, node_ids)
  end

  def spread_objects(node_ids, x, num_obj, obj_node_ids) when x == num_obj do
    hash_id = Integer.to_string(:rand.uniform(9999), 16)
    IO.puts("The hash_id is #{hash_id}")
    # Add it to its root node
    root_node = find_closest(hash_id, node_ids)

    # Add it to the root's object list
    pid = :"#{root_node}"
    :ok = GenServer.call(pid, {:object_add, hash_id})

    # Add it to random duplicates
    dup_node_1 = Enum.random(node_ids)
    pid1 = :"#{dup_node_1}"
    dup_node_2 = Enum.random(node_ids)
    pid2 = :"#{dup_node_2}"

    :ok = GenServer.call(pid1, {:object_add, hash_id})
    :ok = GenServer.call(pid2, {:object_add, hash_id})

    obj_node_ids = obj_node_ids ++ [hash_id]
  end

  def spread_objects(node_ids, x, num_obj, obj_node_ids) do
    hash_id = Integer.to_string(:rand.uniform(9999), 16)
    IO.puts("The hash_id is #{hash_id}")
    # Add it to its root node
    {root_node, _} = find_closest(hash_id, node_ids)

    # Add it to the root's object list
    pid = :"#{root_node}"
    :ok = GenServer.call(pid, {:object_add, hash_id})

    # Add it to random duplicates
    dup_node_1 = Enum.random(node_ids)
    pid1 = :"#{dup_node_1}"
    dup_node_2 = Enum.random(node_ids)
    pid2 = :"#{dup_node_2}"

    :ok = GenServer.call(pid1, {:object_add, hash_id})
    :ok = GenServer.call(pid2, {:object_add, hash_id})

    x = x + 1
    obj_node_ids = obj_node_ids ++ [hash_id]
    spread_objects(node_ids, x, num_obj, obj_node_ids)
  end

  def find_closest(node, list) do
    {ans, out} =
      Enum.reduce(list, {"", 0}, fn item, {nearest, distance} ->
        if maybe_nearer = String.jaro_distance(node, Enum.at(item, 1)) > distance do
          {Enum.at(item, 1), maybe_nearer}
        else
          {nearest, distance}
        end
      end)

    {root_node, dist} = {ans, out}
  end
end

defmodule Find_Neighbors do
  # Make a routing list and return it
  def make_neighbors(node) do
    # Isabel's code comes here
    # Return the neigbor list
  end
end

defmodule Job_done do
  def terminate() do
    # Make a handle call to everyone to remove me
    # Ask Supervisor to kill me
  end
end

defmodule Routing_101 do
  def publish_routing(obj_id, next_node, server_id) do
    if next_node == server_id do
      {node, dist} = next_hop(obj_id, next_node)

      if dist > String.jaro_distance(obj_id, server_id) do
        publish_routing(obj_id, node, server_id)
      else
        1
      end
    else
      {_, _, obj_lst, _, _} = :sys.get_state(:"#{next_node}")

      if obj_id in obj_lst do
        1
      else
        # genserver call
        pid = :"#{next_node}"
        :ok = GenServer.call(pid, {:obj_lnk_add, obj_id, server_id})
        {node, _} = next_hop(obj_id, next_node)
        publish_routing(obj_id, node, server_id)
      end
    end
  end

  def next_hop(obj_id, next_node) do
    p = String.length(next_node) - String.length(String.trim_leading(next_node, obj_id))
    # get the routing table for the next node
    # Check if it works with the name of the node
    {table, _, obj_lst, _, _} = :sys.get_state(:"#{next_node}")
    # Check if its p or p-1
    {:ok, level} = Map.fetch(table, p)
    {node, dist} = Other_jobs.find_closest(obj_id, level)
  end

  def routing_route(obj_id, node_id, n) do
    {_, _, obj_lst, obj_lnk, _} = :sys.get_state(:"#{node_id}")

    if obj_id in obj_lst && n = 0 do
      send_to = 1
    else
      {send_to, n} =
        cond do
          obj_id in obj_lst ->
            {send_to, n} = {node_id, n}

          Map.has_key?(obj_lnk, obj_id) ->
            send_to = Map.get(obj_lnk, obj_id)
            {send_to, n} = {send_to, n}

          true ->
            {next_node, _} = next_hop(obj_id, node_id)
            n = n + 1
            routing_route(obj_id, next_node, n)
        end

      {send_to, n} = {send_to, n}
    end

    {send_to, n} = {send_to, n}
  end
end

# Main Application
nodes = 5
requests = 5
req_rng = Range.new(1, requests)
# Start supervisor with the input arguments
{:ok, pid} = DyServer.start_link(1)
IO.puts("Server Started")

# Start the children
IO.puts("starting the nodes")
last = nodes
node_ids = []
node_ids = Other_jobs.start_children(last, 1, node_ids)

# Spread the objects
num_obj = 10
obj_node_ids = Other_jobs.spread_objects(node_ids, 1, num_obj, obj_node_ids)

# Publish the objects
for node <- node_ids do
  # Check
  {_, _, obj_lst, _, _} = :sys.get_state(:"#{next_node}")

  for object <- obj_lst do
    Routing_101.publish_routing(object, node, node)
  end
end

# Start sending requests
for x <- req_rng do
  for node <- node_ids do
    request_this = Enum.random(obj_node_ids)
    IO.puts("Sending Message to #{request_this}")
    # pid = :"#{node}"
    # :ok = GenServer.call(pid, {:request, send_to})
    {send_to, n} = Routing_101.routing_route(request_this, node, 0)

    if send_to == 1 do
      1
    else
      pid = :"#{send_to}"
      :ok = GenServer.call(pid, {:request, n})
    end
  end
end

# Keeping Count of number of hops and triggering termination

IO.puts("ALL done")

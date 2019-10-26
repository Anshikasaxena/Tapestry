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

    # IO.puts("Got the  child_spec")
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
    # neighbors = Find_Neighbors.make_neighbors(hash_id)
    {:ok, {neighbors, hash_id, obj_lst, obj_lnk, max_hop}}
  end

  @impl true
  def handle_call({:addToTapestry}, _from, state) do
    # pid = Kernel.inspect(self())
    # IO.inspect(state, label: "\nMy #{pid} Initial State")
    my_id = elem(state, 1)

    # OG = N as an object; objects routed by ID
    h_node_pid = contactGatewayNode(self())

    hNodeToRoute(h_node_pid, my_id)
    # IO.inspect(state, label: "\nAdded To Tapestry")

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:receiveHello, from_id}, from, state) do
    # _pid = Kernel.inspect(self())
    # _fid = Kernel.inspect(from_pid)
    # IO.inspect(state, label: "\n #{pid} Received Hello from #{fid}. \nMy old state")
    # IO.inspect(state, label: "\nReceived Hello from #{neighbor_id}. \nMy old state")

    {from_pid, _ok} = from
    new_state = placeInNeighborMap(state, from_id, from_pid)

    # IO.inspect(new_state, label: "\nMy new state")

    {:reply, :ok, new_state}
  end

  def handle_call({:request, hops}, _from, {neighbors, hash_id, obj_lst, obj_lnk, max_hop}) do
    # Change the state of max hops
    IO.puts("My no. of hops is #{hops}")

    max_hop =
      if(hops > max_hop) do
        max_hop = hops
      else
        max_hop
      end

    IO.puts("My no. of hops is #{max_hop}")
    {:reply, :ok, {neighbors, hash_id, obj_lst, obj_lnk, max_hop}}
  end

  @impl true
  def handle_call({:populateNeighbors, my_id, my_pid}, _from, state) do
    # IO.inspect(my_pid, label: "\nIn populateNeighbors server. My pid is")
    # get neighbor map from h
    # {from_pid, _ok} = from
    {neighbor_map, neighbor_id, _, _, _} = state
    j = findJ(my_id, neighbor_id, 0)
    i = j + 1
    # check if level exists
    if(checkIfLevelExists(neighbor_map, j) == true) do
      # go to that level on the Map
      level = getLevel(neighbor_map, j)
      # IO.inspect(level, label: "level")

      # check if there is a neighbor with the same "i" as you
      iInList =
        Enum.any?(level, fn elem ->
          n_i = Enum.at(elem, 0)
          n_i == i
        end)

      if iInList == true do
        neighbor =
          Enum.find(level, fn elem ->
            n_i = Enum.at(elem, 0)
            n_i == i
          end)

        # get close item and route there
        # check it make sure it's not you
        next_neighbor_id = Enum.at(neighbor, 1)
        next_neighbor_pid = Enum.at(neighbor, 2)
        new_j = j + 1
        # IO.puts("here 1")

        if next_neighbor_id != my_id do
          GenServer.call(next_neighbor_pid, {:routeN, new_j, my_id, my_pid}, :infinity)
        end
      else
        # IO.inspect(level, label: "level")
        # copy level map
        for elem <- level do
          # IO.inspect("should add friend")
          n_id = Enum.at(elem, 1)
          n_pid = Enum.at(elem, 2)
          GenServer.cast(my_pid, {:addToNeighborMap, n_id, n_pid})
        end

        # get close item and route there
        # check it make sure it's not you
        neighbor = Enum.at(level, 0)
        next_neighbor_id = Enum.at(neighbor, 1)
        next_neighbor_pid = Enum.at(neighbor, 2)
        new_j = j + 1
        # IO.puts("here 1")

        if next_neighbor_id != my_id do
          GenServer.call(next_neighbor_pid, {:routeN, new_j, my_id, my_pid}, :infinity)
        end
      end

      # IO.puts("here 2")
    else
      # IO.inspect("i don't know")
    end

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:routeN, j, my_id, my_pid}, _from, state) do
    # in neighbors state
    {neighbor_map, _neighbor_id, _, _, _} = state
    # IO.inspect(my_pid, label: "In routeN looking from #{j} neighbor_id")
    # # check if level exists
    if(checkIfLevelExists(neighbor_map, j) == true) do
      # IO.inspect("level #{j} exists")
      # go to that level on the Map
      level = getLevel(neighbor_map, j)
      # get close item and route there
      neighbor = Enum.at(level, 0)
      next_neighbor_id = Enum.at(neighbor, 1)
      next_neighbor_pid = Enum.at(neighbor, 2)
      new_j = j + 1

      if next_neighbor_id != my_id do
        GenServer.call(next_neighbor_pid, {:routeN, new_j, my_id, my_pid}, :infinity)
      end
    else
      # IO.inspect("i don't know")
    end

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:printState}, _from, state) do
    pid = Kernel.inspect(self())
    IO.inspect(state, label: "\n My #{pid} State is")

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:object_add, id}, _from, {neighbors, hash_id, obj_lst, obj_lnk, max_hop}) do
    obj_lst = obj_lst ++ [id]
    {:reply, :ok, {neighbors, hash_id, obj_lst, obj_lnk, max_hop}}
  end

  @impl true
  def handle_call(
        {:obj_lnk_add, obj_id, server_id},
        _from,
        {neighbors, hash_id, obj_lst, obj_lnk, max_hop}
      ) do
    IO.puts("in add")
    obj_lnk = Map.put_new(obj_lnk, obj_id, server_id)

    IO.inspect(obj_lnk, label: "obj_link")
    {:reply, :ok, {neighbors, hash_id, obj_lst, obj_lnk, max_hop}}
  end

  @impl true
  def handle_cast({:addToNeighborMap, neighbor_id, from_pid}, state) do
    # IO.inspect(self(), label: "In add to neighbor map with #{neighbor_id} ")
    new_state = placeInNeighborMap(state, neighbor_id, from_pid)
    {:noreply, new_state}
  end

  def addToTapestry(childPid) do
    GenServer.call(childPid, {:addToTapestry}, :infinity)
  end

  def contactGatewayNode(childPid) do
    children = DynamicSupervisor.which_children(DyServer)
    # get a node from supervisor that is not yourself--> surrogate root
    {_, neighbor_pid, _, _} = Enum.at(children, 1)

    if neighbor_pid != childPid do
      # Returns Node H pid
      _nodeG = neighbor_pid
    else
      {_, neighbor_pid, _, _} = Enum.at(children, 0)

      # Returns Node H pid
      _nodeH = neighbor_pid
    end
  end

  def hNodeToRoute(h_node_pid, my_id) do
    # pid = Kernel.inspect(self())
    # IO.inspect(pid, label: "\nMy PiD ")

    # Send Hello to neighbor no matter what so they can check if they need to add me to their map
    sendHello(h_node_pid, my_id)

    GenServer.call(h_node_pid, {:populateNeighbors, my_id, self()}, :infinity)
    # getHNeighbors(h_node_pid)
  end

  def sendHello(neighbor_pid, new_id) do
    # Node N sends hello to Neighbor new_neighbor  H(i)
    GenServer.call(neighbor_pid, {:receiveHello, new_id}, :infinity)
  end

  def placeInNeighborMap(my_state, from_id, from_pid) do
    # pid = Kernel.inspect(self())
    my_id = elem(my_state, 1)
    # IO.inspect(neighbor_id, label: "\nPlaceInNeighborMap my id is #{pid} and neighbor_id")

    if(my_id != from_id) do
      my_neighborMap = elem(my_state, 0)

      # find j - compare characters to find what level it belongs to
      j = findJ(my_id, from_id, 0)

      # find i
      i =
        if j > 0 do
          j_corrected = j - 1
          # IO.puts("Length of most in common prefix #{j_corrected}")

          _prefix = String.slice(my_id, 0..j_corrected)

          # find i
          i_index = j_corrected + 1
          i = String.at(from_id, i_index)

          # IO.puts("Common prefix between #{my_id} and #{neighbor_id} is #{prefix} and i is: #{i}")
          i
        else
          # i is the first elemment
          i = String.at(from_id, 0)
          i
        end

      # neighbor
      # %{j => [i, neighbor_id, neighbor_pid]}

      # Check if level j exists & insert
      new_my_neighborMap =
        if(my_neighborMap != nil) do
          if Map.has_key?(my_neighborMap, j) == true do
            new_neighbor = [i, from_id, from_pid]

            _new_my_neighborMap =
              updateYourNeighborMap(j, my_neighborMap, new_neighbor, from_pid, my_id)
          else
            # IO.puts("level j not here yet")
            GenServer.cast(from_pid, {:addToNeighborMap, my_id, self()})
            _new_my_neighborMap = Map.put(my_neighborMap, j, [[i, from_id, from_pid]])
          end
        else
          # IO.puts("level j not here yet")
          GenServer.cast(from_pid, {:addToNeighborMap, my_id, self()})
          _new_my_neighborMap = Map.put(my_neighborMap, j, [[i, from_id, from_pid]])
        end

      # update state
      temp_state = Tuple.delete_at(my_state, 0)
      _my_new_state = Tuple.insert_at(temp_state, 0, new_my_neighborMap)
    else
      my_state
    end
  end

  def findJ(my_id, neighbor_id, j) do
    # IO.inspect(j, label: "in findJ with #{my_id} and #{neighbor_id}")
    prefixA = String.slice(my_id, 0..j)
    # IO.inspect(prefixA, label: "prefixA")
    prefixB = String.slice(neighbor_id, 0..j)
    # IO.inspect(prefixB, label: "prefixB")

    if prefixA == prefixB do
      # IO.puts("It's A Match")
      new_j = j + 1
      findJ(my_id, neighbor_id, new_j)
      # new_j
    else
      j
    end
  end

  def updateYourNeighborMap(j, my_neighborMap, new_neighbor, from_pid, my_id) do
    {_current_neighbors, updateedNeighborMap} =
      Map.get_and_update(my_neighborMap, j, fn current_neighbors ->
        # IO.inspect(current_neighbors, label: "current_neighbors")
        # check for duplicates
        if Enum.member?(current_neighbors, new_neighbor) do
          {current_neighbors, current_neighbors}
        else
          GenServer.cast(from_pid, {:addToNeighborMap, my_id, self()})
          update = current_neighbors ++ [new_neighbor]
          sorted_update = Enum.sort(update)
          {current_neighbors, sorted_update}
        end
      end)

    # IO.inspect(updateedNeighborMap, label: "updateedNeighborMap")
    updateedNeighborMap
  end

  def checkIfLevelExists(h_neighbor_map, i) do
    if(Enum.count(h_neighbor_map) > 0) do
      if Map.has_key?(h_neighbor_map, i) == true do
        true
      else
        false
      end
    else
      false
    end
  end

  def getLevel(h_neighbor_map, i) do
    i_level_neighbor_map = Map.fetch(h_neighbor_map, i)

    # IO.inspect(i_level_neighbor_map, label: "#{i}th level NeighborMap_i from H")
    {_, i_level} = i_level_neighbor_map
    i_level
  end

  def printState(childPid) do
    GenServer.call(childPid, {:printState}, :infinity)
  end
end

defmodule Other_jobs do
  def start_children(last, x, node_ids) when x == last do
    new_id = :rand.uniform(900_000)
    sha = :crypto.hash(:sha, "#{new_id}")
    hash_id = sha |> Base.encode16()
    IO.puts("The hash_id is #{hash_id}")
    neighbors = %{}
    obj_lst = []
    obj_lnk = %{}
    max_hop = 0
    DyServer.start_child(neighbors, hash_id, obj_lst, obj_lnk, max_hop)
    # IO.puts("ALL children started")
    node_ids = node_ids ++ [hash_id]
  end

  def start_children(last, x, node_ids) do
    new_id = :rand.uniform(900_000)
    sha = :crypto.hash(:sha, "#{new_id}")
    hash_id = sha |> Base.encode16()
    # IO.puts("The hash_id is #{hash_id}")
    node_ids = node_ids ++ [hash_id]
    # IO.inspect(node_ids)
    neighbors = %{}
    obj_lst = []
    obj_lnk = %{}
    max_hop = 0
    DyServer.start_child(neighbors, hash_id, obj_lst, obj_lnk, max_hop)
    x = x + 1
    start_children(last, x, node_ids)
  end

  def spread_objects(node_ids, x, num_obj, obj_node_ids) when x == num_obj do
    new_id = :rand.uniform(900_000)
    sha = :crypto.hash(:sha, "#{new_id}")
    hash_id = sha |> Base.encode16()
    # Add it to its root node
    {root_node, _} = find_closest_root(hash_id, node_ids)
    IO.inspect(root_node, label: "The object_id is #{hash_id} and has root node")
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
    new_id = :rand.uniform(900_000)
    sha = :crypto.hash(:sha, "#{new_id}")
    hash_id = sha |> Base.encode16()
    # IO.puts("The object_id is #{hash_id}")
    # Add it to its root node
    {root_node, _} = find_closest_root(hash_id, node_ids)

    # Add it to the root's object list
    pid = :"#{root_node}"
    IO.inspect(root_node, label: "The object_id is #{hash_id} and has root node")
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

  def find_closest_root(node, list) do
    {ans, out} =
      Enum.reduce(list, {"", 0}, fn item, {nearest, distance} ->
        if (maybe_nearer = String.jaro_distance(node, item)) > distance do
          {item, maybe_nearer}
        else
          {nearest, distance}
        end
      end)

    {root_node, dist} = {ans, out}
    IO.inspect(root_node, label: "root_node")
    {root_node, dist} = {ans, out}
  end

  def find_closest(node, list) do
    # {ans, out} =
    #   Enum.reduce(list, {"", 0}, fn item, {nearest, distance} ->
    #     if maybe_nearer = String.jaro_distance(node, Enum.at(item, 1)) > distance do
    #       {Enum.at(item, 1), maybe_nearer}
    #     else
    #       {nearest, distance}
    #     end
    #   end)
    #
    # {ans, out} = ls

    item = Enum.at(list, 0)
    distance = String.jaro_distance(node, Enum.at(item, 1))
    min_node = Enum.at(item, 1)

    newminList =
      for item <- list do
        nodefound = Enum.at(item, 1)
        maybe_nearer = String.jaro_distance(node, nodefound)

        if maybe_nearer < distance do
          IO.inspect(maybe_nearer, label: "maybe_nearer")
          min_node = nodefound
          {min_node, maybe_nearer}
        else
          IO.inspect(distance, label: "distance")
          {min_node, distance}
        end
      end

    distanceList = []

    distanceList =
      Enum.map(newminList, fn item ->
        {node, dist} = item
        distanceList = distanceList ++ [dist]
      end)

    IO.inspect(distanceList, label: "distanceList")

    minDist = Enum.min(distanceList)

    index =
      Enum.find_index(distanceList, fn x ->
        x == minDist
      end)

    IO.inspect(index, label: "index")

    {min_node2, distance2} = Enum.at(newminList, index)
    IO.inspect(min_node2, label: "min_node2")
    IO.inspect(distance2, label: "distance2")

    {root_node, dist} = {min_node2, distance2}
  end
end

defmodule Routing_101 do
  def publish_routing(obj_id, next_node, server_id) do
    if next_node == server_id do
      IO.puts("The server node analysis - #{server_id}")
      IO.puts("THE object is #{obj_id}")
      {node, dist} = next_hop(obj_id, next_node)
      IO.puts("The next closest thing is #{node}")
      # IO.puts("#{obj_ - #{server_id}} inside #{server_id} if")
      # IO.inspect(node, label: "#{next_node} going to")

      # if (distance between new friend and object ) < (distance between current and object)
      # ?give up object
      dist2 = String.jaro_distance(obj_id, server_id)
      IO.puts("Dist b/w object and next closest node is #{dist}")
      IO.puts("Dist b/w object and server node is #{dist2}")

      if dist < dist2 do
        IO.puts("Im not a root, still a server and so we go to node #{node}")
        publish_routing(obj_id, node, server_id)
      else
        IO.puts("I am root")
      end
    else
      IO.puts("Moving forward")
      IO.puts("You're at #{next_node}")
      {_, _, obj_lst, _, _} = :sys.get_state(:"#{next_node}")

      if obj_id in obj_lst do
        IO.puts("You've arrived at the root node")
      else
        # genserver call
        pid = :"#{next_node}"
        IO.puts("Adding object link")
        :ok = GenServer.call(pid, {:obj_lnk_add, obj_id, server_id})
        IO.puts("Added link")
        {node, _} = next_hop(obj_id, next_node)
        # IO.inspect(node, label: "#{next_node} going to")
        IO.puts("The next closest thing is #{node}")
        IO.puts("YOUre going to #{node}")
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
    if(:error != Map.fetch(table, 0)) do
      if(p == 0) do
        i = String.at(obj_id, 0)
        level = Map.fetch(table, 0)
        {_, level_p} = level

        found_neighbor =
          Enum.find(level_p, fn x ->
            [index, neighbor, pid] = x
            index == i
          end)

        if(found_neighbor == nil) do
          {nil, 0}
        else
          [index, neighbor, pid] = found_neighbor
          {neighbor, 0}
        end
      else
        {level_ind, level_list} = Enum.at(table, p)

        {node, dist} = Other_jobs.find_closest(obj_id, level_list)
      end
    else
      {nil, 0}
    end
  end

  def routing_route(obj_id, node_id, n) do
    {_, _, obj_lst, obj_lnk, _} = :sys.get_state(:"#{node_id}")

    {send_to, n} =
      if obj_id in obj_lst && (n = 0) do
        {send_to, n} = {1, 0}
      else
        {send_to, n} =
          cond do
            obj_id in obj_lst ->
              {send_to, n} = {node_id, n}

            # Map.has_key?(obj_lnk, obj_id) ->
            #   send_to = Map.get(obj_lnk, obj_id)
            #   {send_to, n} = {send_to, n}

            true ->
              {next_node, _} = next_hop(obj_id, node_id)

              if next_node != nil do
                n = n + 1
                routing_route(obj_id, next_node, n)
              else
                {node_id, n}
              end
          end

        {send_to, n} = {send_to, n}
      end

    {send_to, n} = {send_to, n}
  end
end

# Take command line arguments
arguments = System.argv()

# Make them into integers
numNodes = String.to_integer(Enum.at(arguments, 0))
numRequests = String.to_integer(Enum.at(arguments, 1))

req_rng = Range.new(1, numRequests)

# Start supervisor with the input arguments
{:ok, pid} = DyServer.start_link(1)
IO.puts("Server Started")

# Start the children
IO.puts("starting the nodes")
last = numNodes
node_ids = []
node_ids = Other_jobs.start_children(last, 1, node_ids)

children = DynamicSupervisor.which_children(DyServer)

# Adding to Tapestry
for x <- children do
  {_, childPid, _, _} = x
  Nodes.addToTapestry(childPid)
end

:timer.sleep(2000)

# Spread the objects
num_obj = 3
obj_node_ids = []
obj_node_ids = Other_jobs.spread_objects(node_ids, 1, num_obj, obj_node_ids)

for x <- children do
  {_, childPid, _, _} = x
  Nodes.printState(childPid)
end

# # Publish the objects
# for node <- node_ids do
#   # Check
#   {_, _, obj_lst, _, _} = :sys.get_state(:"#{node}")
#
#   for object <- obj_lst do
#     Routing_101.publish_routing(object, node, node)
#   end
# end

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

maxhopList = []

maxhopList =
  for x <- children do
    {_, childPid, _, _} = x
    Nodes.printState(childPid)
    {_, _, _, _, max_hop} = :sys.get_state(childPid)
    maxhopList = maxhopList ++ [max_hop]
  end

flatmaxhopList = List.flatten(maxhopList)
IO.inspect(flatmaxhopList, label: "maxhopList")

maxHop = Enum.max(flatmaxhopList)
IO.inspect(maxHop, label: "maxHop")

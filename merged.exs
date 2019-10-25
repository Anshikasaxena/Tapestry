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
end

defmodule Other_jobs do
  def start_children(last, x, node_ids) when x == last do
    new_id = :rand.uniform(10000)
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
    new_id = :rand.uniform(10000)
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

# children = DynamicSupervisor.which_children(DyServer)
#
# for x <- children do
#   {_, childPid, _, _} = x
#   Nodes.addToTapestry(childPid)
# end

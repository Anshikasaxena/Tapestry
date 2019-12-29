# Tapestry: A Resilient Global-Scale Overlay for Service Deployment 
## About 
For this project, the paper - Tapestry: A Resilient Global-Scale Overlay for Service Deployment by Ben Y. Zhao, Ling Huang, Jeremy Stribling, Sean C. Rhea, Anthony D. Joseph and John D. Kubiatowicz is implemented using the Elixir actor model.Tapestry is a peer-to-peer overlay routing infrastructure offering efficient, scalable, location-independent routing of messages directly to nearby copies of an object or service using only localized resources. Tapestry supports a generic decentralized object location and routing applications programming interface using a self-repairing, soft-state-based routing layer. 

## Input 
To run project use:

<p align="center">
‘mix run project.exs [number of nodes] [number of requests]’ 
</p>

## Output 
Maximum number of hops traversed for all requests for all nodes.

## Performance 
Traversing 2000 nodes with a maxHop of 1 i.e. O(log b N) which is the performance achieved in the paper 

## Link 
Link to the paper is https://pdos.csail.mit.edu/~strib/docs/tapestry/tapestry_jsac03.pdf

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `project` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:project, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/project3](https://hexdocs.pm/project3).




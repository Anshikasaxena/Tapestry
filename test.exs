test1 = "1A23"
test2 = "32A1"

if test1 < test2 do
  IO.puts("correct")
else
  IO.puts("incorrect")
end

list = ["D08B", "69FA", "8DD9", "E133", "F3FD"]
node = "1835"

{ans, out} =
  Enum.reduce(list, {"", FFFF}, fn item, {nearest, distance} ->
    if (maybe_nearer = String.jaro_distance(node, item)) < distance do
      {item, maybe_nearer}
    else
      {nearest, distance}
    end
  end)

{root_node, dist} = {ans, out}
IO.inspect(root_node, label: "root_node")

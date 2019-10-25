test1 = "1A23"
test2 = "32A1"

if test1 < test2 do
  IO.puts("correct")
else
  IO.puts("incorrect")
end

list = ["D08B", "69FA", "8DD9", "E133", "F3FD"]
objID = "18A5"
stringObjID = String.to_integer(objID, 16)
# for every item in the list calculate my difference
diffList = []

diffList =
  for item <- list do
    stringItemID = String.to_integer(item, 16)
    diff = stringItemID - stringObjID
    diffList = diffList ++ [abs(diff)]
  end

# get the min of the differences
minValue = Enum.min(diffList)

index =
  Enum.find_index(diffList, fn x ->
    x == minValue
  end)

closests = Enum.at(list, index)
{closests, minValue}

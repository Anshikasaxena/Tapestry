test1 = "1A23"
test2 = "32A1"

if test1 < test2 do
  IO.puts("correct")
else
  IO.puts("incorrect")
end

list = ["D08B", "69FA", "8DD9", "E133", "F3FD"]
objID = "18A5"

# for every char in list element
#   check if char from obj id ==  index
charList = String.to_charlist(objID)
char1 = Enum.at(charList, 0)

IO.inspect(char1, label: "objID")
Enum.each()

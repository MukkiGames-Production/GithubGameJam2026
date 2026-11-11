extends Node
class_name Operators

enum Type {
	NOT,
	LEFT_SHIFT,
	RIGHT_SHIFT,
	AND,
	OR,
	XOR,
	NAND,
	NOR,
	XNOR
}

# var operator = Operators.FROM_STRING.get("NOT", -1)
const FROM_STRING = {
	"NOT": Type.NOT,
	"<<": Type.LEFT_SHIFT,
	">>": Type.RIGHT_SHIFT,
	"AND": Type.AND,
	"OR": Type.OR,
	"XOR": Type.XOR,
	"NAND": Type.NAND,
	"NOR": Type.NOR,
	"XNOR": Type.XNOR
}

static func is_binary(value: String) -> bool:
	if value.is_empty():
		return false
	for bit in value:
		if bit != "0" and bit != "1":
			return false
	return true


## Empty string means invalid/missing inputs. Work on strings to avoid integer overflow.
## NOT takes one input; shifts take a value and optional binary shift amount (default 1).
## Other operators reduce all inputs, padding on the left to the widest input.
static func evaluate(operator: String, inputs: Array[String]) -> String:
	operator = operator.to_upper()
	if not FROM_STRING.has(operator) or inputs.is_empty():
		return ""
	var width := 0
	for value in inputs:
		if not is_binary(value):
			return ""
		width = maxi(width, value.length())
	if operator == "NOT":
		return _invert(inputs[0]) if inputs.size() == 1 else ""
	if operator == "<<" or operator == ">>":
		if inputs.size() > 2:
			return ""
		width = inputs[0].length()
		var amount := 1
		if inputs.size() == 2:
			amount = 0
			for bit in inputs[1]:
				amount = mini(width, amount * 2 + int(bit))
		amount = mini(width, amount)
		if operator == "<<":
			return inputs[0].substr(amount) + "0".repeat(amount)
		return "0".repeat(amount) + inputs[0].left(width - amount)
	if inputs.size() < 2:
		return ""
	var result := inputs[0].lpad(width, "0")
	for index in range(1, inputs.size()):
		var value := inputs[index].lpad(width, "0")
		var combined := ""
		for bit in width:
			match operator:
				"AND", "NAND":
					combined += "1" if result[bit] == "1" and value[bit] == "1" else "0"
				"OR", "NOR":
					combined += "1" if result[bit] == "1" or value[bit] == "1" else "0"
				"XOR", "XNOR":
					combined += "1" if result[bit] != value[bit] else "0"
		result = combined
	return _invert(result) if operator in ["NAND", "NOR", "XNOR"] else result


static func _invert(value: String) -> String:
	var result := ""
	for bit in value:
		result += "1" if bit == "0" else "0"
	return result

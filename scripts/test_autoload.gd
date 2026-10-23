extends Node

func _ready():
	TestSingleton.test_method()
	var val = TestSingleton.test_value
	print("test_value =", val)
	var returned = TestSingleton.get_value()
	print("get_value() =", returned)
	
	# Also test: does get_node("/root/TestSingleton") work?
	var root = get_tree().get_root()
	var singleton = root.get_node("TestSingleton")
	if singleton:
		singleton.test_method()
		print("get_node approach works too!")
	
	print("ALL TESTS PASSED")
	get_tree().quit()

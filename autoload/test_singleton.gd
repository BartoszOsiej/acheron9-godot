class_name TestSingleton
extends Node

var test_value: int = 42

func test_method() -> void:
	print("TestSingleton.test_method() called successfully!")

func get_value() -> int:
	return test_value

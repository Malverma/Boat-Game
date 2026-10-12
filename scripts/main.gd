extends Node
## Entry point: switches between the title screen and the game world.

var _current: Node


func _ready() -> void:
	show_menu()


func show_menu() -> void:
	var m := MainMenu.new()
	m.start_game.connect(_start)
	_swap(m)


func _start(new_game: bool) -> void:
	if new_game or not Game.load_game():
		Game.new_game()
		Game.save_game()
	var w := World.new()
	w.quit_to_menu.connect(show_menu)
	_swap(w)


func _swap(n: Node) -> void:
	get_tree().paused = false
	if _current != null:
		_current.queue_free()
	_current = n
	add_child.call_deferred(n)

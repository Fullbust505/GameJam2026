extends Node2D

@export var tile_type: TileTypes.Type = TileTypes.Type.CHALLENGE
@export var tile_index: int = 0

@onready var label: Label = $Label

signal tile_entered(player_index: int, tile_type: TileTypes.Type, tile_index: int)

func _ready():
	update_visual()

func set_tile_type(type: TileTypes.Type, index: int):
	tile_type = type
	tile_index = index
	update_visual()

func update_visual():
	match tile_type:
		TileTypes.Type.CHALLENGE:
			$ColorRect.color = Color(1.0, 0.3, 0.3, 1)
			label.text = "Challenges"
		TileTypes.Type.SHOP:
			$ColorRect.color = Color(0.3, 1.0, 0.3, 1)
			label.text = "Shop"
		TileTypes.Type.EVENT:
			$ColorRect.color = Color(0.3, 0.3, 1.0, 1)
			label.text = "EVents"

func _on_area_entered(body: Node2D):
	if body is PlayerPiece:
		tile_entered.emit(body.player_index, tile_type, tile_index)

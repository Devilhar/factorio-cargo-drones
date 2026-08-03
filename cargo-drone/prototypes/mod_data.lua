
local mod_data = {
	type = "mod-data",
	name = "cargo-drone-data",
	data_type = "string",
	data = {
		-- Register drones here by adding them
		drones = {
			--[[
			# Example

			## Name of the drone used as key
			["cargo-drone"] = {
				## The data version so the Cargo drone mod knows how to handle the data. Just copy the value from here.
				version = 1,
				## The shift offset to know where Depot cables should attach to
				cable = {
					attachment_offset = { x = 0, y = -9 },
					attachment_shadow_offset = { x = 14, y = 0 },
				},
				## These values are used by Deployers to be able to render the drone
				deployer = {
					## The data for the sprite that will be displayed
					body = {
						spawn_offset = { 0, 12.275 },
						prepare_offset = { 0, 9.275 },

						## filename, width, height, and scale can be omitted if position is omitted.
						filename = "__cargo-drone__/graphics/cargo-drone.png",
						width = 502,
						height = 252,
						scale = 0.5,

						## Shift is always required as it tells Deployers at which height the drone should stop at.
						shift = util.by_pixel(0, -284),

						## The x and y for the sprites. Will create sprites for each of the four positions set.
						## The names of the created sprites are:
						## 		cargo-drone-deployer-{Name of the drone}-north-1
						## 		cargo-drone-deployer-{Name of the drone}-north-2
						## 		cargo-drone-deployer-{Name of the drone}-north-3
						## 		cargo-drone-deployer-{Name of the drone}-north-4
						## 		cargo-drone-deployer-{Name of the drone}-east-1
						## 		cargo-drone-deployer-{Name of the drone}-east-2
						## 		cargo-drone-deployer-{Name of the drone}-east-3
						## 		cargo-drone-deployer-{Name of the drone}-east-4
						## 		cargo-drone-deployer-{Name of the drone}-south-1
						## 		cargo-drone-deployer-{Name of the drone}-south-2
						## 		cargo-drone-deployer-{Name of the drone}-south-3
						## 		cargo-drone-deployer-{Name of the drone}-south-4
						## 		cargo-drone-deployer-{Name of the drone}-west-1
						## 		cargo-drone-deployer-{Name of the drone}-west-2
						## 		cargo-drone-deployer-{Name of the drone}-west-3
						## 		cargo-drone-deployer-{Name of the drone}-west-4
						## The number following each sprite represents the number of quaters being displayed. So the ones ending in 1 will only show the top 25% of the sprite. 3 shows the top 75%. Etc.
						## If a direction is not present, its sprites will have to be manually created.
						positions = {
							north	= { 0, 125 },
							east	= { 0, 1129 },
							south	= { 0, 2133 },
							west	= { 0, 3137 },
						},
					},
					## The data for the shadow that will be displayed
					shadow = {
						prepare_offset = { -11.56875, 0 },
						
						## filename, width, height, and scale can be omitted if position is omitted.
						filename = "__cargo-drone__/graphics/cargo-drone-shadow.png",
						width = 502,
						height = 502,
						scale = 0.5,

						## Shift is always required as it tells Deployers which height the drone should stop at.
						shift = util.by_pixel(383, -16),

						## The x and y for the shadow sprites. Will create a sprite for each of the four positions set.
						## The names of the created sprites are:
						## 		cargo-drone-deployer-{Name of the drone}-shadow-north
						## 		cargo-drone-deployer-{Name of the drone}-shadow-east
						## 		cargo-drone-deployer-{Name of the drone}-shadow-south
						## 		cargo-drone-deployer-{Name of the drone}-shadow-west
						## If a direction is not present, its sprite will have to be manually created.
						positions = {
							north	= { 0, 0 },
							east	= { 0, 1004 },
							south	= { 0, 2008 },
							west	= { 0, 3012 },
						},
					}
				}
			}
			]]
		},

		-- The following values exist after data-final-fixes has run.

		-- Array[string] of all items with a place_result for a drone.
		-- All items are automatically found, no need to add it manually.
		-- items = {},

		-- The inventory size of all drones.
		-- inventory_size = 10,

		-- If any drone has burnt results inventory size larger than 0.
		-- burnt_results_enabled = false,
	},
}

data:extend{
    mod_data
}
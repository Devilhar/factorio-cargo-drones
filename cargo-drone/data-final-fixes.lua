
local cargo_drone = data.raw["car"]["cargo-drone"]
local deployer_dummy_fuel_drone = data.raw["car"]["cargo-drone-deployer-dummy-fuel-drone"]

deployer_dummy_fuel_drone.energy_source.fuel_inventory_size = cargo_drone.energy_source.fuel_inventory_size
deployer_dummy_fuel_drone.energy_source.fuel_categories = cargo_drone.energy_source.fuel_categories

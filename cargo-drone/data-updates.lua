
if settings.startup["cargo-drone-lightning-exemption"].value then
	for _, planet in pairs(data.raw["planet"]) do
		if planet.lightning_properties then
			table.insert(planet.lightning_properties.exemption_rules, {
				type = "id",
				string = "cargo-drone",
			})
		end
	end
end

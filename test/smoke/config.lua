local H = dofile('test/harness.lua')

vector3 = function(x, y, z) return { x = x, y = y, z = z } end
vector4 = function(x, y, z, w) return { x = x, y = y, z = z, w = w } end

dofile('config.lua')

H.equal(type(Config.craftables.wire_bundle), 'table', 'default component recipe is configured')
H.equal(type(Config.craftables.vehicle_repair_kit), 'table', 'default finished-item recipe is configured')
H.equal(Config.areas.public_workbench.model, 'prop_tool_bench02', 'default public area spawns a bench model')
H.equal(Config.areas.mechanic_workshop.zone.type, 'box', 'default mechanic area targets existing world geometry')

H.finish()

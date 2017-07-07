--[[
=================================================
                   LIBRARIES
=================================================
]]
local bump = require 'bump'
local inspect = require 'inspect'

--[[
=================================================
              useful global vars
=================================================
]]
GRAVITY = 600
KEYS = {
  ['a'] = false,       -- Move left
  ['d'] = false,       -- Move right
  ['w'] = false,       -- Jump / Move up (on ladder)
  ['s'] = false,       -- Move down on ladder, drop through platform
  ['escape'] = false,  -- Quit the game / TODO: Change to menu
}
WORLD = bump.newWorld()
-- OBJECT types:
--   * 'static' - only collision and collision behaviors
--   * 'dynamic' - is subject to gravity and velocity changes
MAP_OBJECTS = {}
-- Maps
MAP_BASE_PATH = 'maps/'
MAP_CURRENT = require 'maps/map1'
-- Tilesize
TILESIZE = 16

-- Different velocity constants
frc, acc, dec, top, low = 300, 400, 3500, 350, 50
maxFallVelocity = 325

--[[
=================================================
                  Player :-)

  States: 'idle', 'walk', 'jump', 'fall', 'die'
=================================================
]]
player = {}

function player:applyVelocities(dt)
  self:setPosition(self.x + self.vx * dt, self.y + self.vy * dt)
end

function player:collision(dt)
  -- Gather calculated values
  local futureX, futureY = self.x + (self.vx * dt), self.y + (self.vy * dt)
  local nextX, nextY, cols, len = WORLD:move(self, futureX, futureY)

  -- Loop collision map
  for i=1, len do
    local col = cols[i]
    -- TODO: add logic for interacting with different objects
    if col.normal.x ~= 0 then
      self:setVel(0)
    end
    if col.normal.y ~= 0 then
      self:setVel(nil, 0)
    end
  end

  -- Set position to calculated positions
  self:setPosition(nextX, nextY)
end

function player:init(x, y, vx, vy, width, height, state)
  -- mutable variables
  self.name = 'player'
  self.jumpCounter = 0
  self.height = height
  self.state = state or 'idle'
  self.vx = vx
  self.vy = vy
  self.width = width
  self.x = x
  self.y = y
  -- draw level
  self.z = 1

  -- constants
  self.colors = {140, 255, 235}
  self.jumpvel = -175
  self.maxJumps = 2
  self.objectType = 'dynamic'
end

function player:jump()
  if KEYS['w'] and self.jumpCounter < self.maxJumps then
    self:setVel(nil, self.jumpvel)
    self.jumpCounter = self.jumpCounter + 1
    KEYS['w'] = false
  end
end

function player:move(dt)
  local vx, vy = self.vx, self.vy

  if KEYS['a'] then
    if vx > 0 then
      vx = vx - dec * dt
    elseif vx > -top then
      vx = vx - acc * dt
    end
  elseif KEYS['d'] then
    if vx < 0 then
      vx = vx + dec * dt
    elseif vx < top then
      vx = vx + acc * dt
    end
  else
    if math.abs(vx) < low then
      vx = 0
    elseif vx > 0 then
      vx = vx - frc * dt
    elseif vx < 0 then
      vx = vx + frc * dt
    end
  end

  self:setVel(vx, vy)
end

function player:setPosition(x, y)
  self.x = x
  self.y = y
end

function player:setVel(vx, vy)
  self.vx = vx or self.vx
  self.vy = vy or self.vy
end

function player:updateState()
  if self.vx ~= 0 and self.vy == 0 then
    self.state = 'walk'
  end
  if self.vy < 0 then
    self.state = 'jump'
  end
  if self.vy > 0 then
    self.state = 'fall'
  end
  if self.vx == 0 and self.vy == 0 then
    self.state = 'idle'
  end
  if self.state == 'walk' or self.state == 'idle' then
    self.jumpCounter = 0
  end
end

--[[
=================================================
              Misc util functions
=================================================
]]
function applyGravity(objects, dt)
  for _, v in pairs(objects) do
    if v.objectType ~= 'static' then
      if v.vy < maxFallVelocity then
        v.vy = v.vy + GRAVITY * dt
      else
        v.vy = maxFallVelocity
      end
    end
  end
end

function debugprint()
  print(player.state, player.jumpCounter)
end

function distance(x1, y1, x2, y2)
  return math.sqrt( (x2 - x1)^2 + (y2 - y1)^2 )
end

function drawObjects(objects)
  for _, v in pairs(objects) do
    local colors = v.colors or {255,255,255}
    love.graphics.setColor(unpack(colors))
    if v.name == 'solid' or v.name == 'player' then
      love.graphics.rectangle('fill', v.x, v.y, v.width, v.height)
    end
  end
end

function getPlayerSpawn(mapObjects)
  local x, y
  for _, v in pairs(mapObjects) do
    if v.name == 'spawn' then
      x = v.x
      y = v.y
    end
  end
  if not x and not y then
    error('No player spawn object')
  end
  return x, y
end

function initWorldObjects(objects)
  for _, v in pairs(objects) do
    WORLD:add(v, v.x, v.y, v.width, v.height)
  end
end

function loadCurrentMapObjects(map)
  local mapObjects = {}
  for y=1, #MAP_CURRENT do
    local row = MAP_CURRENT[y]
    for x=1, #row do
      local num = row[x]
      local ox, oy = x-1, y-1
      local o = {}
      o.x = ox * TILESIZE
      o.y = oy * TILESIZE
      o.width = TILESIZE
      o.height = TILESIZE
      -- object type defaults to static
      o.objectType = 'static'
      if num == 1 then
        o.name = 'solid'
      elseif num == 2 then
        o.name = 'floater'
      elseif num == 3 then
        o.name = 'objective'
      elseif num == 4 then
        o.name = 'ladder'
      elseif num == 6 then
        o.name = 'bounce'
      elseif num == 7 then
        o.name = 'hidden'
      elseif num == 8 then
        o.name = 'spawn'
      end
      if o.name then
        table.insert(mapObjects, o)
      end
    end
  end
  return mapObjects
end

--[[
=================================================
                MAIN FUNCTIONS                 
=================================================
--]]

function love.load()
  MAP_OBJECTS = loadCurrentMapObjects(MAP_CURRENT)
  local spawnX, spawnY = getPlayerSpawn(MAP_OBJECTS)
  player:init(spawnX, spawnY, 0, 0, TILESIZE, TILESIZE)
  table.insert(MAP_OBJECTS, player)
  initWorldObjects(MAP_OBJECTS)
end

function love.draw()
  drawObjects(MAP_OBJECTS)
end


function love.update(dt)
  player:move(dt)
  player:applyVelocities(dt)
  player:collision(dt)
  -- state must be updated after collision calculations
  player:updateState()
  player:jump()
  
  -- apply gravity to OBJECTS
  applyGravity(MAP_OBJECTS, dt)

  -- debug section aka printing to console
  -- debugprint()
end

function love.keypressed(key) 
  for k, v in pairs(KEYS) do
    if k == key and not v then
      KEYS[k] = true
    end
  end
end

function love.keyreleased(key)
  for k, v in pairs(KEYS) do
    if k == key and v then
      KEYS[k] = false
    end
  end

  if key == 'escape' then
    love.event.quit()
  end
end
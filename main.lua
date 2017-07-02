--[[
=================================================
                   LIBRARIES
=================================================
]]
local inspect = require 'inspect'
local bump = require 'bump'

--[[
=================================================
              useful global vars
=================================================
]]
WORLD = bump.newWorld()
GRAVITY = 600
KEYS = {
  ['a'] = false,       -- Move left
  ['d'] = false,       -- Move right
  ['w'] = false,       -- Jump / Move up (on ladder)
  ['s'] = false,       -- Move down on ladder, drop through platform
  ['escape'] = false,  -- Quit the game / TODO: Change to menu
}

--[[
=================================================
                  Player :-)

  States: 'idle', 'walk', 'jump', 'fall', 'die'
        Object types: 'static', 'dynamic' 
=================================================
]]
player = {}

function player:init(x, y, vx, vy, width, height, state)
  -- mutable variables
  self.x = x
  self.y = y
  self.vx = vx
  self.vy = vy
  self.width = width
  self.height = height
  self.state = state or 'idle'
  self.jumpCounter = 0
  -- draw level
  self.z = 1

  -- constants
  self.speed = 350
  self.jump = -290
  self.turnAround = 60
  self.colors = {140, 255, 235}
  self.objectType = 'dynamic'
end

function player:setVelocities(vx, vy)
  self.vx = vx or self.vx
  self.vy = vy or self.vy
end

function player:setPosition(x, y)
  self.x = x
  self.y = y
end

function player:move(dt)
  if KEYS['a'] then
    if self.vx > 0 then
      self:setVelocities(-self.turnAround)
    end
    self:setVelocities(self.vx - self.speed * dt)
  end
  if KEYS['d'] then
    if self.vx < 0 then
      self:setVelocities(self.turnAround)
    end
    self:setVelocities(self.vx + self.speed * dt)
  end
  if KEYS['w'] and self.jumpCounter <= 1 then
    self.vy = self.jump
    self.jumpCounter = self.jumpCounter + 1
  end
end

function player:applyVelocities(dt)
  self:setPosition(self.x + self.vx * dt, self.y + self.vy * dt)
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

function player:collision(dt)
  -- Gather calculated values
  local futureX, futureY = self.x + (self.vx * dt), self.y + (self.vy * dt)
  local nextX, nextY, cols, len = WORLD:move(self, futureX, futureY)

  -- Loop collision map
  for i=1, len do
    local col = cols[i]
    -- TODO: add logic for interacting with moving platforms?
    if col.normal.x ~= 0 then
      self:setVelocities(0)
    end
    if col.normal.y ~= 0 then
      self:setVelocities(nil, 0)
    end
  end

  -- Set position to calculated positions
  self:setPosition(nextX, nextY)
end

--[[
=================================================
              Misc util functions
=================================================
]]
function applyGravity(objects, dt)
  for _, v in pairs(objects) do
    if v.objectType ~= 'static' then
      v.vy = v.vy + GRAVITY * dt
    end
  end
end

function initWorldObjects(objects)
  for _, v in pairs(objects) do
    WORLD:add(v, v.x, v.y, v.width, v.height)
  end
end

function drawObjects(objects)
  for _, v in pairs(objects) do
    local colors = v.colors or {255,255,255}
    love.graphics.setColor(unpack(colors))
    love.graphics.rectangle('fill', v.x, v.y, v.width, v.height)
  end
end

--[[
=================================================
                MAIN FUNCTIONS                 
=================================================
--]]

function love.load()
  local SPAWN = {
    x = 0,
    y = 0
  }
  player:init(SPAWN.x, SPAWN.y, 0, 0, 32, 32)
  objects = {player, {x=0, y=350, width=love.graphics.getWidth()*(2/5), height=50, objectType='static'}}

  initWorldObjects(objects)
end

function love.update(dt)
  player:move(dt)
  player:applyVelocities(dt)
  player:collision(dt)
  -- state must be updated after collision calculations
  player:updateState()
  
  -- debug section aka printing to console
  print(player.state)

  -- apply gravity to objects
  applyGravity(objects, dt)
end

function love.draw()
  drawObjects(objects)
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
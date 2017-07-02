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

-- Different velocity constants
frc, acc, dec, top, low = 300, 400, 3500, 350, 50
maxFallVelocity = 325

--[[
=================================================
                  Player :-)

  States: 'idle', 'walk', 'jump', 'fall', 'die'
        Object types: 'static', 'dynamic' 
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
    -- TODO: add logic for interacting with moving platforms?
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
  self.jumpvel = -290
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

function drawObjects(objects)
  for _, v in pairs(objects) do
    local colors = v.colors or {255,255,255}
    love.graphics.setColor(unpack(colors))
    love.graphics.rectangle('fill', v.x, v.y, v.width, v.height)
  end
end

function initWorldObjects(objects)
  for _, v in pairs(objects) do
    WORLD:add(v, v.x, v.y, v.width, v.height)
  end
end

--[[
=================================================
                MAIN FUNCTIONS                 
=================================================
--]]
function love.draw()
  drawObjects(objects)
end

function love.load()
  local SPAWN = {
    x = 0,
    y = 0
  }
  player:init(SPAWN.x, SPAWN.y, 0, 0, 32, 32)
  objects = {player, {x=0, y=350, width=love.graphics.getWidth()*(2/5), height=50, objectType='static'}}

  initWorldObjects(objects)
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

function love.update(dt)
  player:move(dt)
  player:applyVelocities(dt)
  player:collision(dt)
  -- state must be updated after collision calculations
  player:updateState()
  player:jump()
  
  -- apply gravity to objects
  applyGravity(objects, dt)

  -- debug section aka printing to console
  debugprint()
end
--[[
=================================================
                   LIBRARIES
=================================================
]]
local bump = require 'bump'
local inspect = require 'inspect'
local Camera = require 'camera'

-- FYI: terminology for collidable things are called either objects or blocks,
-- just assume they mean the same thing

--[[
=================================================
              useful global vars
=================================================
]]
MAX_BULLET_DISTANCE = 1000
GRAVITY = 600
KEYS = {
  ['a'] = false,       -- Move left
  ['d'] = false,       -- Move right
  ['w'] = false,       -- Jump / Move up (on ladder)
  ['s'] = false,       -- Move down on ladder, drop through platform
  ['escape'] = false,  -- Quit the game / TODO: Change to menu
  ['left'] = false,
  ['right'] = false,
  ['up'] = false,
  ['down'] = false,
}
WORLD = bump.newWorld()

-- OBJECT types:
--   * 'static' - only collision and collision behaviors
--   * 'dynamic' - is subject to gravity and velocity changes
-- OBJECT names:
--   * 'solid' - solid static block
--   * 'floater' - enemy drone
--   * 'objective' - the object the player wants to collect
--   * 'player' - self explanatory
--   * 'ladder' - ladder object, allows player to climb
--   * 'bounce' - object bounces player up like a trampoline
--   * 'hidden' - hidden door object that is reveal when touched
--   * 'spawn' - object which is used for setting initial player position
MAP_OBJECTS = {}
MAP_BASE_PATH = 'maps/'
MAP_CURRENT = require (MAP_BASE_PATH..'map1')

TILESIZE = 32

-- Different velocity constants
frc, acc, dec, top, low = 300, 400, 3500, 350, 50
maxFallVelocity = 325

-- Images!
playerImage = love.graphics.newImage('player.jpg')

-- collision filter for WORLD:move
local function collisionFilter(item, other)
  if other.name == 'spawn' or other.name == 'objective' or other.name == 'bullet' then
    return 'cross'
  end
  return 'slide'
end

--[[
=================================================
                  Bullets!
=================================================
]]
bullets = {}

function bullets.new(x1, y1, x2, y2, width, height, vel)
  local b = {
    x1=x1,
    y1=y1,
    x2=x2,
    y2=y2,
    width=width,
    height=height,
    vel=vel,
    dx=x2-x1,
    dy=y2-y1,
    dist=distance(x1, y1, x2, y2),
    directionX=0,
    directionY=0,
    name='bullet',
    state='active',
    objectType='dynamic',
    damage=10,
  }
  WORLD:add(b, x1, y1, width, height)
  return b
end

function bullets.move(b, dt)
  local hit = false

  b.directionX = b.dx / b.dist
  b.directionY = b.dy / b.dist

  local futureX = b.x1 + b.directionX * b.vel * dt
  local futureY = b.y1 + b.directionY * b.vel * dt
  local goalX, goalY, cols, len = WORLD:move(b, futureX, futureY, collisionFilter)

  for i=1, len do
    local col = cols[i]
    if col.type == 'slide' and col.other.name ~= 'player' then
      hit = true
    end
    if col.other.name == 'hidden' then
      col.other.state = 'dead'
    end
    if col.other.name == 'floater' then
      col.other.health = col.other.health - b.damage
      if col.other.health < 0 then
        col.other.state = 'dead'
      end
    end
  end

  b.x1 = goalX
  b.y1 = goalY

  return hit
end

function bullets.updateAll(objects, dt)
  loopSpecificObjects(objects, 'bullet', function(i, v)
    local hit = bullets.move(v, dt)
    if hit then
      v.state = 'dead'
    end
  end)
end

--[[
=================================================
                  Player :-)
  States: 'idle', 'walk', 'jump', 'fall', 'dead'
=================================================
]]
player = {}

function player:applyVelocities(dt)
  self:setPosition(self.x + self.vx * dt, self.y + self.vy * dt)
end

function player:collision(dt)
  -- Gather calculated values
  local futureX, futureY = self.x + (self.vx * dt), self.y + (self.vy * dt)
  local nextX, nextY, cols, len = WORLD:move(self, futureX, futureY, collisionFilter)

  -- Loop collision map
  for i=1, len do
    local col = cols[i]

    if col.type == 'slide' then
      if col.normal.x ~= 0 then
        self:setVel(0)
      end
      if col.normal.y ~= 0 then
        self:setVel(nil, 0)
      end
    end

    if col.other.name == 'bounce' then
      self:setVel(nil, self.jumpVel*1.8)
    end

    if col.other.name == 'objective' and self.health ~= self.maxHealth then
      self:increaseHealth(true, col.other.buff)
      col.other.state = 'dead'
    end

    if col.other.name == 'ladder' and (col.normal.x == 1 or col.normal.x == -1) then
      if KEYS['a'] or KEYS['d'] then
        self:setVel(nil, self.climbVel)
        self.jumpCounter = 1
      end
    end
  end

  -- Set position to calculated positions
  self:setPosition(nextX, nextY)
end

function player:increaseHealth(increaseOnce, increment, dt)
  if increaseOnce then
    self.health = self.health + increment
  else
    self.health = self.health + increment * dt
  end
  if self.health > self.maxHealth then
    self.health = self.maxHealth
  end
end

function player:decreaseHealth(decreaseOnce, decrement, dt)
  -- Difference between 'health - decrement * dt' and
  -- 'health - decrement' is that the former will be used
  -- only to decrease health multiple times (called in update)
  -- whereas the latter will be used in removing health once
  -- (not constantly updated)
  if decreaseOnce then
    self.health = self.health - decrement
  else
    self.health = self.health - decrement * dt
  end
  if self.health < 0 then
    self.health = 0
    self.state = 'dead'
  end
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
  -- self.z = 1
  local h = 100
  self.health = h
  self.maxHealth = h

  -- constants
  self.colors = {255,255,255}
  self.climbVel = -80
  self.bulletVel = 800
  self.jumpVel = -250
  self.maxJumps = 2
  self.objectType = 'dynamic'
end

function player:jump()
  if KEYS['w'] and self.jumpCounter < self.maxJumps and self.state ~= 'climb' then
    self:setVel(nil, self.jumpVel)
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

function player:shoot(objects)
  local b
  local x1, y1, x2, y2
  local w, h = 4, 4
  local bufferSpace = 6
  if KEYS['right'] then
    x1 = self.x + self.width + bufferSpace
    x2 = x1 + 10
    y1 = self.y + self.height / 2
    y2 = y1
    local vel
    if self.vx < 0 then
      vel = self.bulletVel
    else
      vel = self.vx + self.bulletVel
    end
    b = bullets.new(x1, y1, x2, y2, w, h, vel)
    KEYS['right'] = false
  elseif KEYS['left'] then
    x1 = self.x - w - bufferSpace
    x2 = x1 - 10
    y1 = self.y + self.height / 2
    y2 = y1
    local vel
    if self.vx > 0 then
      vel = self.bulletVel
    else
      vel = math.abs(self.vx) + self.bulletVel
    end
    b = bullets.new(x1, y1, x2, y2, w, h, vel)
    KEYS['left'] = false
  elseif KEYS['up'] then
    x1 = self.x + self.width / 2
    x2 = x1
    y1 = self.y - bufferSpace
    y2 = y1 - 10
    local vel
    if self.vy < 0 then
      vel = self.bulletVel
    else
      vel = math.abs(self.vy) + self.bulletVel
    end
    b = bullets.new(x1, y1, x2, y2, w, h, self.bulletVel)
    KEYS['up'] = false
  elseif KEYS['down'] then
    x1 = self.x + self.width / 2
    x2 = x1
    y1 = self.y + self.height + bufferSpace
    y2 = y1 + 10
    local vel
    if self.vy < 0 then
      vel = self.bulletVel
    else
      vel = math.abs(self.vy) + self.bulletVel
    end
    b = bullets.new(x1, y1, x2, y2, w, h, self.bulletVel)
    KEYS['down'] = false
  end
  if b then
    objects[#objects+1] = b
  end
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
  if self.vy == self.climbVel then
    self.state = 'climb'
  end
  if self.state == 'walk' or self.state == 'idle' then
    self.jumpCounter = 0
  end
end

function player:drawHealthBar()
  local healthRatio = self.health / 100
  local healthBarWidth = 40
  local healthBarHeight = 10
  love.graphics.setColor(0,255,0)
  love.graphics.rectangle('fill', player.x - 8, player.y - healthBarHeight - 3,
    healthBarWidth * healthRatio, healthBarHeight)
end

--[[
=================================================
              Misc util functions
=================================================
]]
function applyGravity(objects, dt)
  for _, v in pairs(objects) do
    if v.objectType ~= 'static' and v.name ~= 'bullet' then
      if v.vy < maxFallVelocity then
        v.vy = v.vy + GRAVITY * dt
      else
        v.vy = maxFallVelocity
      end
    end
  end
end

function debugprint(dt)
  loopSpecificObjects(MAP_OBJECTS, 'floater', function(i, v)
    print(inspect(v))
  end)
end

function distance(x1, y1, x2, y2)
  return math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
end

-- easy draw function
-- once objects start becoming more and more complex
-- they should probably have specific draw functions
-- see floaters.drawHomingLine
function drawObjects(objects)
  for _, v in pairs(objects) do
    local colors = v.colors or {255,255,255}
    if v.name == 'solid' or v.name == 'hidden' then
      -- Hidden objects should be the same color as solid objects
      -- So they're hidden... duh!
      love.graphics.setColor(unpack(colors))
    elseif v.name == 'floater' then
      -- remove circle drawing in real gameplay
      -- love.graphics.setColor(100,100,100)
      -- love.graphics.circle('line', v.x+v.width/2, v.y+v.height/2, v.radius)
      -- Red is obviously hostile
      love.graphics.setColor(255,0,0)
    elseif v.name == 'objective' then
      -- Green to represent something good?
      love.graphics.setColor(0,255,0)
    elseif v.name == 'ladder' then
      -- Grey because why not
      love.graphics.setColor(140,140,140)
    elseif v.name == 'bounce' then
      -- Magenta because I don't know what color this should be
      love.graphics.setColor(255,0,255)
    end
    if v.name ~= 'spawn' and v.name ~= 'player' and v.name ~= 'bullet' then
      love.graphics.rectangle('fill', v.x, v.y, v.width, v.height)
    end
    if v.name == 'player' then
      love.graphics.setColor(v.colors)
      love.graphics.draw(playerImage, v.x, v.y)
    end
    if v.name == 'bullet' then
      love.graphics.setColor(255,0,255)
      love.graphics.rectangle('fill', v.x1, v.y1, v.width, v.height)
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
      -- object type defaults to 'static'
      o.objectType = 'static'
      -- if objects are dynamic then they must have velocities as well
      -- object state defaults to 'unactive'
      o.state = 'unactive'
      o.hit = false
      if num == 1 then
        o.name = 'solid'
      elseif num == 2 then
        o.name = 'floater'
        o.radius = 300
        o.damage = 10
        o.health = 30
      elseif num == 3 then
        o.name = 'objective'
        o.buff = 30
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

function loopSpecificObjects(objects, name, f)
  for i, v in pairs(objects) do
    if v.name == name then
      f(i, v)
    end
  end
end

function removeObjects(objects)
  for i, v in pairs(objects) do
    if v.name == 'bullet' then
      if distance(v.x1, v.y1, player.x, player.y) > MAX_BULLET_DISTANCE then
        objects[i] = nil
        WORLD:remove(v)
      end
    end
    if v.state == 'dead' and v.name ~= 'player' then
      objects[i] = nil
      WORLD:remove(v)
    end
  end
end

--[[
=================================================
                   Floaters
=================================================
--]]

local floaters = {}

function floaters.checkRadius(objects)
  loopSpecificObjects(objects, 'floater', function(i, v)
    local dist = distance(v.x+v.width/2, v.y+v.height/2,
      player.x+player.width/2, player.y+player.height/2)
    if dist < v.radius then
      v.state = 'attack'
    else
      v.state = 'unactive'
    end
  end)
end

function floaters.attackPlayer(objects, dt)
  loopSpecificObjects(objects, 'floater', function(i, v)
    if v.state == 'attack' then
      player:decreaseHealth(false, v.damage, dt)
    end
  end)
end

function floaters.drawHomingLine(objects)
  loopSpecificObjects(objects, 'floater', function(i, v)
    if v.state == 'attack' then
      love.graphics.setColor(255,0,0)
      love.graphics.line(v.x+v.width/2, v.y+v.height/2,
        player.x+player.width/2, player.y+player.height/2)
    end
  end)
end

--[[
=================================================
                MAIN FUNCTIONS                 
=================================================
--]]

function love.load()
  -- initialize camera
  camera = Camera(0, 0)
  -- initialize map objects from map
  MAP_OBJECTS = loadCurrentMapObjects(MAP_CURRENT)
  -- initialize player and player spawn
  local spawnX, spawnY = getPlayerSpawn(MAP_OBJECTS)
  player:init(spawnX, spawnY, 0, 0, TILESIZE-4, TILESIZE-4)

  -- insert player into the map objects
  table.insert(MAP_OBJECTS, player)

  -- initialize bump world objects
  initWorldObjects(MAP_OBJECTS)
end

function love.draw()
  if player.state ~= 'dead' then
    camera:attach()
      drawObjects(MAP_OBJECTS)
      floaters.drawHomingLine(MAP_OBJECTS)
      player:drawHealthBar()
    camera:detach()
  else
    love.graphics.setColor(255,0,0)
    love.graphics.print('You have died!', love.graphics.getWidth()/2-32,
      love.graphics.getHeight()/2-6)
  end
end


function love.update(dt)
  if player.state ~= 'dead' then
    player:move(dt)
    player:applyVelocities(dt)
    player:collision(dt)
    -- state must be updated after collision calculations
    player:updateState()
    player:jump()
    player:shoot(MAP_OBJECTS)
    
    -- apply gravity to OBJECTS
    applyGravity(MAP_OBJECTS, dt)

    -- debug section aka printing to console
    -- debugprint()

    -- update camera position
    camera:lookAt(player.x, player.y)

    -- floater updates
    floaters.checkRadius(MAP_OBJECTS)
    floaters.attackPlayer(MAP_OBJECTS, dt)

    -- bullet
    bullets.updateAll(MAP_OBJECTS, dt)

    -- update dead objects
    removeObjects(MAP_OBJECTS)
  end
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
  if key == '`' then
    love.event.quit('restart')
  end
end
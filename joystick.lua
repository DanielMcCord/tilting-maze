-----------------------------------------------------------------------------------------
--
-- joystick.lua
--
-- Module that implements a display group that acts like a joystick to simulate the
-- device accelerometer. Dispatches "accelerometer" events to the Runtime when used.
-- After loading the module, the overall size radius is in joystick.rOuter.
-- Call joystick:create(x, y) to create the joystick at the given screen position.
-----------------------------------------------------------------------------------------

-- The joystick module with its data fields
local joystick = { 
	rInner = 20,    -- radius of inner moving part
	rOuter = 40,    -- radius of outer part
}


-- Return x pinned to be in the range of min to max
local function pin(x, min, max)
	if x < min then
		return min
	elseif x > max then 
		return max
	end
	return x
end

-- Create and dispatch a simulated accelerometer event with the given G values
local function simAccelerometer(xG, yG, zG)
	local event = { 
		name = "accelerometer", 
		target = Runtime,
		isShake = false,
		deltaTime = 0,
		xGravity = xG, yGravity = yG, zGravity = zG,
		xInstant = 0, yInstant = 0, zInstant = 0,
		xRaw = xG, yRaw = yG, zRaw = zG,
	}
	Runtime:dispatchEvent(event)
end

-- Touch listener for joystick control
local function touchStick(event)
	local stick = event.target
	if event.phase == "began" then
		-- Take the touch focus
		display.getCurrentStage():setFocus(stick)
	elseif event.phase == "moved" then
		-- Move joystick relative to initial touch position
		local r = joystick.rInner
		local dx = pin(event.x - event.xStart, -r, r)
		local dy = pin(event.y - event.yStart, -r, r)
		stick.x = dx
		stick.y = dy

		-- Send accelometer event
		local xG = dx / r
		local yG = -dy / r
		simAccelerometer(xG, yG, 0)
	else  -- ended/cancelled
		-- Re-center stick and release the touch focus
		stick.x = 0
		stick.y = 0
		display.getCurrentStage():setFocus(nil)
		simAccelerometer(0, 0, 0)
	end
	return true
end

-- Create and return a joystick at the given position
function joystick:create(x, y)
	-- Make a display group with two concentric circles
	local group = display.newGroup()
	group.x = x
	group.y = y
	local outer = display.newCircle(group, 0, 0, joystick.rOuter)
	outer:setFillColor(0.6)
	local stick = display.newCircle(group, 0, 0, joystick.rInner)
	stick:setFillColor(0.3)

	-- Activate and return it to caller
	stick:addEventListener("touch", touchStick)
	group:toFront()  -- Make sure the joystick is in front of any other graphics
	return group
end


-- Return the joystick module
return joystick

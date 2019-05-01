-----------------------------------------------------------------------------------------
--
-- main.lua
--
-----------------------------------------------------------------------------------------

-- Load required Corona modules
local widget = require("widget")
local physics = require("physics")

-- Get the screen metrics (use the entire device screen area)
local WIDTH = display.actualContentWidth
local HEIGHT = display.actualContentHeight
local xMin = display.screenOriginX
local yMin = display.screenOriginY
local xMax = xMin + WIDTH
local yMax = yMin + HEIGHT
local xCenter = (xMin + xMax) / 2
local yCenter = (yMin + yMax) / 2

-- Game metrics
local dyTopBar = 40                       -- height of the UI bar at the top
local yControls = yMin + dyTopBar / 2     -- y position for UI buttons
local ballRadius = 12                     -- radius of the ball
local xStart = xMin + ballRadius + 5                  -- starting x for the ball
local yStart = yMin + dyTopBar + ballRadius + 5       -- starting y for the ball

-- UI controls
local blockSegControl   -- segmented control to pick block type
local resetBtn    -- Reset button
local editBtn     -- Edit button
local doneBtn     -- Done button
local clearBtn    -- Clear button

-- Game objects
local ball         -- the ball that bounces around
local blocks       -- display group for blocks that get created

-- Game state
local editing = false   -- true when editing the game layout

-- Data file information
local prefFileName = "userPrefs.txt"    -- user preferences file 

-- Data for a block is stored in a table with one of the following formats:
-- Wall: { t = "wall", x = xPos, y = yPos, w = width, h = height }
-- Dot:  { t = "dot", x = xPos, y = yPos, r = radius }

-- Block data corresponding to the segments in blockSegControl
local blockDataSegments = {
	{ t = "wall", x = 0, y = 0, w = 50, h = 8 },   -- Horz
	{ t = "wall", x = 0, y = 0, w = 8, h = 50 },   -- Vert
	{ t = "dot", x = 0, y = 0, r = 8 },            -- Dot
}

-- Make and return a ball object at the given position
function makeBall(x, y)
	local b = display.newCircle(x, y, ballRadius)
	b:setFillColor(1, 0, 0)  -- red
	physics.addBody(b, { bounce = 0.7, radius = ballRadius })
	b.isSleepingAllowed = false   -- accelerometer will not wake ball on its own
	return b
end

-- Make and return a border wall at the given position and size
function makeBorder(x, y, width, height) 
	local b = display.newRect(x, y, width, height)
	physics.addBody(b, "static", { bounce = 0.2 })
	return b
end

-- Make and return a block with the given block data (see "Data for a block" above)
function makeBlock(data)
	local block = nil
	if data.t == "wall" then
		block = display.newRect(blocks, data.x, data.y, data.w, data.h)
		physics.addBody(block, "static", { bounce = 0.2 })
	elseif data.t == "dot" then
		block = display.newCircle(blocks, data.x, data.y, data.r)
		physics.addBody(block, "static", { radius = data.r, bounce = 0.2 })
	else
		error("Unknown block type: " .. data.t)
		return nil
	end
	block.t = data.t   -- remember the block type inside the display object
	return block
end

-- Turn editing mode on or off. Pass true or false for mode.
function setEditMode(mode)
	editing = mode
	blockSegControl.isVisible = mode
	clearBtn.isVisible = mode
	doneBtn.isVisible = mode
	resetBtn.isVisible = not mode
	editBtn.isVisible = not mode
	ball.isVisible = not mode
end

-- Make and return a UI button with the given label, position, and listener function
function makeButton(label, x, y, listener)
	return widget.newButton{ 
		x = x, 
		y = yControls, 
		label = label, 
		textOnly = true, 
		onRelease = listener 
	}
end

-- Handle a press on the Reset button
function onReset()
	-- Move ball back to the starting position and stop its motion
	ball.x = xStart
	ball.y = yStart
	ball:setLinearVelocity(0, 0)
end

-- Handle the result of the Clear alert
function onClearAlert(event)
	if event.action == "clicked" and event.index == 2 then
		-- Remove all blocks and start over with an empty group
		blocks:removeSelf()
		blocks = display.newGroup()
	end
end

-- Handle a press on the Clear button
function onClear()
	-- Put up a confirmation alert to make sure the user wants to nuke all their work
	native.showAlert("Custom Maze", "Delete all maze blocks?", 
			{ "Cancel", "Delete" }, onClearAlert)
end

-- Handle a press on the Edit button
function onEdit()
	-- Start editing mode
	setEditMode(true)

	-- Load the selected block type from the user pref file, if any
	local path = system.pathForFile(prefFileName, system.DocumentsDirectory)
	local str = readDataFile(path)
	if str then
		blockSegControl:setActiveSegment(tonumber(str))
	end
end

-- Handle a press on the Done button
function onDone()
	-- End editing mode and reset the game
	setEditMode(false)
	onReset()

	-- Save the selected block type to the user pref file
	local str = tostring(blockSegControl.segmentNumber)
	local path = system.pathForFile(prefFileName, system.DocumentsDirectory)
	writeDataFile(str, path)
end

-- Dragging a block allows it to be moved in edit mode
function onBlockTouch(event)
	if editing then
		local block = event.target
		if event.phase == "began" then
			display.getCurrentStage():setFocus(block)  -- set touch focus to block
		elseif event.phase == "moved" then
			-- Adjust block position while dragged
			block.x = event.x
			block.y = event.y
		else  -- ended or cancelled
			display.getCurrentStage():setFocus(nil)  -- release touch focus
		end
	end
	return true
end

-- Touching the screen places a new block in edit mode
function onScreenTouch(event)
	if editing and event.phase == "began" then
		-- Get the block data table for the selected segment and make the block
		local blockData = blockDataSegments[blockSegControl.segmentNumber]
		local block = makeBlock(blockData)

		-- Move the block to the tap location
		block.x = event.x
		block.y = event.y

		-- Set touch capture to the block to allow it to be dragged right away
		block:addEventListener( "touch", onBlockTouch )
		display.getCurrentStage():setFocus(block)
	end
	return true
end

-- Handle accelerometer events. Simulate gravity in direction of device tilt.
function accelEvent(event)
	--print(event.xRaw, event.yRaw)
	physics.setGravity(event.xRaw * 10, -event.yRaw * 10)
end

-- Save the string str to a data file with the given path name. 
-- Return true if successful, false if failure.
function writeDataFile(str, pathName)
	local file = io.open(pathName, "w")
	if file then
		file:write(str)
		io.close(file)
		print("Saved to: " .. pathName)
		return true
	end
	return false
end

-- Load the contents of a data file with the given path name.
-- Return the contents as a string or nil if failure (e.g. file does not exist).
function readDataFile(pathName)
	local str = nil
	local file = io.open(pathName, "r")
	if file then
		str = file:read("*a")  -- read entire file as a single string
		io.close(file)
		if str then
			print("Loaded from: " .. pathName)
		end
	end
	return str
end

-- Init the game
function initGame()
	-- Prepare screen and physics engine
	display.setStatusBar(display.HiddenStatusBar)
	physics.start()
	physics.setGravity(0, 0)   -- gravity will be set by accelerometer events

	-- Make the ball object and the blocks group
	ball = makeBall(xStart, yStart)
	blocks = display.newGroup()

	-- Make walls around the borders of the screen
	local thickness = 4
	makeBorder(xCenter, yMin + dyTopBar / 2, WIDTH, dyTopBar)  -- top with room for UI bar
	makeBorder(xCenter, yMax, WIDTH, thickness)  -- bottom
	makeBorder(xMin, yCenter, thickness, HEIGHT)  -- left
	makeBorder(xMax, yCenter, thickness, HEIGHT)  -- right

	-- Make segmented control for choosing the block type
	blockSegControl = widget.newSegmentedControl{
		x = xCenter,
		y = yControls,
		segments = { "Horz", "Vert", "Dot" },
	}

	-- Make the the UI buttons
	resetBtn = makeButton("Reset", xMin + 30, yControls, onReset)
	clearBtn = makeButton("Clear", xMin + 30, yControls, onClear)
	editBtn = makeButton("Edit", xMax - 30, yControls, onEdit)
	doneBtn = makeButton("Done", xMax - 30, yControls, onDone)

	-- Start in the non-editing state
	setEditMode(false)

	-- Load and show the joystick control if running on a simulator
	if system.getInfo("environment") == "simulator" then
		local joystick = require("joystick")
		local offset = joystick.rOuter + 6
		joystick:create(xMax - offset, yMax - offset)
	end

	-- Start the event listeners
	Runtime:addEventListener( "accelerometer", accelEvent )
	Runtime:addEventListener( "touch", onScreenTouch )
end

-- Init and start the game
initGame()

-----------------------------------------------------------------------------------------
--
-- main.lua
--
-- Author:		Daniel McCord
-- Instructor:	Dave Parker
-- Course:		CSCI 79
-- Semester:	Spring 2019
-- Assignment:	Gravity Maze
--
-----------------------------------------------------------------------------------------

--[[
Gravity Maze Rubric
[DONE]User can place Goals and Traps in custom maze
	5.0 pts
[DONE]Hitting Goal wins, hitting Trap loses
	10.0 pts
[DONE]Block data table generated from custom maze
	10.0 pts
[DONE]Maze data saved via JSON to Documents directory
	10.0 pts
[DONE]Custom maze restored from saved data
	10.0 pts
[DONE]Segmented Control for 5 levels
	5.0 pts
[DONE]Tutorial level using static data
	10.0 pts
[DONE]Levels 1-3 load from data files in Resource directory
	15.0 pts
[DONE]Current level # saved and restored
	5.0 pts
[DONE]Levels switch properly
	10.0 pts
[TODO]Code quality and structure
	10.0 pts
--]]

-- Load required Corona modules
local widget = require("widget")
local physics = require("physics")
local json = require("json")

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
local levelSegControl   -- segmented control to pick maze level
local resetBtn    -- Reset button
local editBtn     -- Edit button
local doneBtn     -- Done button
local clearBtn    -- Clear button

-- UI display
local levelEndedText -- Text that displays when the level ends
local lock -- Lock image that appears when loading a level that is not yet available

-- Game objects
local ball         -- the ball that bounces around
local blocks       -- display group for blocks that get created

-- Game state
local editing = false   -- true when editing the game layout
local levelEnded = false -- true when the level has ended
local currentLevel -- The numerical index of the currently loaded level
local highestLevelWon = 0 -- the highest level the user has beaten

-- Data file information
local prefFileName = "userPrefs.txt"    -- user preferences file 
local customMazeName = "customMaze.txt" -- custom maze level file

-- The layout data for the tutorial level.
local tutorialLayout = {
	{y=44.888893127441,x=134.51852416992,t="wall",w=8,h=50},
	{y=126.0740814209,x=49.777778625488,t="wall",w=50,h=8},
	{y=235.11111450195,t="goal",x=47.407409667969,r=8},
	{y=340,t="trap",x=263.70370483398,r=8},
	{y=86.962966918945,x=211.55555725098,t="wall",w=8,h=50},
	{y=164.59259033203,x=254.81480407715,t="wall",w=8,h=50},
	{y=282.51852416992,x=262.51852416992,t="wall",w=50,h=8},
	{y=356,x=46.222221374512,t="wall",w=50,h=8},
	{y=349.48147583008,x=115.55555725098,t="wall",w=50,h=8},
	{y=328.74075317383,x=150.51852416992,t="wall",w=8,h=50},
	{y=303.85186767578,x=233.48147583008,t="wall",w=8,h=50},
	{y=361.33334350586,x=233.48147583008,t="wall",w=8,h=50},
	{y=441.33334350586,x=159.40740966797,t="wall",w=50,h=8},
	{y=33.037040710449,t="goal",x=119.70370483398,r=8}
}

local tutorialMessage = "Tilt to move. Avoid red traps. Reach green goal to win."

local levels = { 
	{ label = "T", t = "static", data = tutorialLayout, message = tutorialMessage},
	{ label = "1", t = "res", file = "level1.txt" },
	{ label = "2", t = "res", file = "level2.txt" },
	{ label = "3", t = "res", file = "level3.txt" },
	{ label = "C", t = "doc", file = customMazeName, canEdit = true },
}

-- Constants
local DEFAULT_LEVEL = 1
local LEVELS_LOCK = false

-- Data for a block is stored in a table with one of the following formats:
-- Wall: { t = "wall", x = xPos, y = yPos, w = width, h = height }
-- Dot:  { t = "goal" or "trap", x = xPos, y = yPos, r = radius }

-- Block data corresponding to the segments in blockSegControl
local blockDataSegments = {
	{ t = "wall", x = 0, y = 0, w = 50, h = 8 },   -- Horz
	{ t = "wall", x = 0, y = 0, w = 8, h = 50 },   -- Vert
	{ t = "trap", x = 0, y = 0, r = 8 },           -- Trap
	{ t = "goal", x = 0, y = 0, r = 8 },           -- Goal
}

-- functions
local makeBall
local endLevel
local makeBorder
local makeBlock
local setEditMode
local makeButton
local onReset
local onClearAlert
local onClear
local onEdit
local onDone
local onBlockTouch
local onScreenTouch
local accelEvent
local writeDataFile
local readDataFile
local loadLevel
local onLevelSelect
local initGame

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

-- Ends the level, winning or losing depending on what kind of block is collided with.
function endLevel ( event )
	if event.phase == "began" then
		local t = event.target.t
		if t == "trap" then
			levelEndedText = display.newText{
				text = "YOU LOSE",
				x = WIDTH / 2,
				y = HEIGHT / 2,
				font = native.systemFontBold,
				align = "center"
			}
		elseif t == "goal" then
			levelEndedText = display.newText{
				text = "YOU WIN",
				x = WIDTH / 2,
				y = HEIGHT / 2,
				font = native.systemFontBold,
				align = "center"
			}
			highestLevelWon = math.max( highestLevelWon, currentLevel )
		else
			error( "Collided with unexpected block type." )
		end
		transition.to( 
			levelEndedText,
			{
				time = 5000,
				xScale = 4,
				yScale = 4,
				alpha = 0,
				onComplete = levelEndedText.removeSelf,
			}
		)
		levelEnded = true
		physics.pause( )
	end
end

-- Make and return a block with the given block data (see "Data for a block" above)
function makeBlock(data)
	local block
	if data.t == "wall" then
		block = display.newRect(blocks, data.x, data.y, data.w, data.h)
		physics.addBody(block, "static", { bounce = 0.2 })
	elseif data.t == "goal" or data.t == "trap" then
		block = display.newCircle(blocks, data.x, data.y, data.r)
		if data.t == "goal" then
			block:setFillColor( 0, 255, 0 )
		else -- data.t == "trap"
			block:setFillColor( 255, 0, 0 )
		end
		physics.addBody(block, "static", { radius = data.r, bounce = 0.2 })
		
		-- Ends the level, winning or losing depending on what type of block it is.
		--[[
		block.collision = function ( self, event )
			print(self, event, self.t, event.target)
			if event.phase == "began" then
				local t = event.target.t
				if t == "goal" then

				elseif t == "trap" then

				elseif not t then
					error( "Collided with block that has no defined type." )
				else
					error( "Level ended unexpectedly from collision with block of type \""
						.. t .. "\". This will not count as a win or loss." )
				end
			end
		end
		--]]
		block:addEventListener( "collision", endLevel )
	else
		error("Unknown block type: " .. data.t)
	end
	block.t = data.t   -- remember the block type inside the display object
	return block
end

-- Turn editing mode on or off. Pass true or false for mode.
function setEditMode(mode)
	editing = mode
	blockSegControl.isVisible = mode
	levelSegControl.isVisible = not mode
	clearBtn.isVisible = mode
	doneBtn.isVisible = mode
	resetBtn.isVisible = not mode
	editBtn.isVisible = not mode and levels[currentLevel].canEdit
	-- Create ball when not in editing mode. Destroy it otherwise.
	if mode then
		if ball then
			ball:removeSelf( )
			ball = nil
		end
		-- Only need to check this when entering editing mode
		if levelEnded then
			levelEndedText:removeSelf( )
			levelEndedText = nil
			levelEnded = false
		end
	else
		onReset()
		if mode then
			physics.pause( )
		end
	end
end

-- Make and return a UI button with the given label, position, and listener function
function makeButton(label, x, y, listener)
	return widget.newButton{ 
		x = x, 
		y = y, 
		label = label, 
		textOnly = true, 
		onRelease = listener 
	}
end

-- Handle a press on the Reset button
function onReset()
	-- Get rid of the lock if it is on-screen
	display.remove(lock)
	-- Destroy the ball if it exists
	display.remove(ball)
	-- Make a new ball
	ball = makeBall( xStart, yStart )
	ball.x = xStart
	ball.y = yStart
	ball:setLinearVelocity(0, 0)
	if levelEnded == true then
		transition.cancel( levelEndedText )
		display.remove( levelEndedText )
		levelEndedText = nil
		levelEnded = false
	end
	physics.start( )
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
	onReset()
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

	--[[-- Save the selected block type to the user pref file
	local str = tostring(blockSegControl.segmentNumber)
	local path = system.pathForFile(prefFileName, system.DocumentsDirectory)
	writeDataFile(str, path)--]]
	-- Save the current level data as JSON to the custom maze file
	local dat = {}
	for i = 1, blocks.numChildren do
		dat[i] = {}
		dat[i].t = blocks[i].t
		dat[i].x = blocks[i].x
		dat[i].y = blocks[i].y
		if blocks[i].path.radius then
			dat[i].r = blocks[i].path.radius
		else
			dat[i].w = blocks[i].width
			dat[i].h = blocks[i].height
		end
	end
	local path = system.pathForFile( customMazeName, system.DocumentsDirectory )
	writeDataFile( json.encode( dat ), path )
	loadLevel(currentLevel)
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
		blockData.x = event.x
		blockData.y = event.y
		local block = makeBlock(blockData)

		-- Move the block to the tap location
		--[[block.x = event.x
		block.y = event.y--]]

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

-- Loads a level indexed in the levels table.
-- Returns true if successful, false if failure.
function loadLevel ( index )
	local l = levels[index]
	-- Remove all blocks and start over with an empty group
	blocks:removeSelf()
	blocks = display.newGroup()
	if l then
		if editBtn then
			editBtn.isVisible = l.canEdit == true
		end
		local levelData = {} -- temporarily holds all the data for the level
		if l.t == "static" then -- load level from static data
			levelData = l.data
		else -- attempt to load level from file
			local dir
			if l.t == "doc" then
				dir = system.DocumentsDirectory
			elseif l.t == "res" then
				dir = system.ResourceDirectory
			else
				return false
			end
			local path = system.pathForFile( levels[index].file, dir )
			local jsonStr = readDataFile( path )
			if jsonStr then
				levelData = json.decode( jsonStr )
			end
		end
		for i = 1, #levelData do
			makeBlock( levelData[i] )
		end
		currentLevel = index
		onReset()
		-- Check if the level is unlocked yet
		if LEVELS_LOCK and index > highestLevelWon + 1 then
			-- If locked, disable physics to prevent play and display a lock on the screen.
			physics.pause()
			lock = display.newImage( "lock.png", xCenter, yCenter )
			lock.xScale = .5
			lock.yScale = .5
		end
		return true
	else
		return false
	end
end

-- Changes the level to the one selected on the segmented control
function onLevelSelect( event )
	if loadLevel( event.target.segmentNumber ) then
	else 
		error( "Could not load level: " .. event.target.segmentLabel )
	end
end

-- Init the game
function initGame()
	-- Prepare screen and physics engine
	display.setStatusBar(display.HiddenStatusBar)
	physics.start()
	physics.setGravity(0, 0)   -- gravity will be set by accelerometer events

	-- Make the ball object and the blocks group
	--ball = makeBall(xStart, yStart)
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
		segments = { "Horz", "Vert", "Trap", "Goal" },
	}

	loadLevel( DEFAULT_LEVEL )

	-- Construct a table of just the labels 
	local segLabels = {}
	for i = 1, #levels do
		segLabels[i] = levels[i].label
	end

	-- Make segmented control for choosing the maze level
	levelSegControl = widget.newSegmentedControl{
		x = xCenter,
		y = yControls,
		segmentWidth = math.min(50, 200/#segLabels),
		segments = segLabels,
		onPress = onLevelSelect,
		defaultSegment = DEFAULT_LEVEL -- Makes the default level the custom maze
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

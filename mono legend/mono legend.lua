numLanes = 5


halfLanes = 0
oddNumLanes = true
if numLanes % 2 == 0 then
	oddNumLanes = false
	halfLanes = numLanes / 2
else
	oddNumLanes = true
	halfLanes = (numLanes -1) / 2
end

GameplaySettings{
		usepuzzlegrid = false,
        greypercent=0,
        colorcount=1,
        usetraffic = true,
        automatic_traffic_collisions = false, -- the game shouldn't check for block collisions since we'll be doing that ourselves in this script
        jumpmode="none",
        matchcollectionseconds=1.5,
        greyaction="normal", -- "eraseall"  -- "eraseblock"
		
		trafficCompression = 1,
		--track generation settings
		gravity=-.65,
        playerminspeed = 0.1,--so the player is always moving somewhat
        playermaxspeed = 5.0,--2.9
        minimumbestjumptime = 2.5,--massage the track until a jump of at least this duration is possible
        uphilltiltscaler = 2.0,--1.5,--set to 1 for a less extreme track
        downhilltiltscaler = 2.0,--1.5,--set to 1 for a less extreme track
        uphilltiltsmoother = 0.03,
        downhilltiltsmoother = 0.06,
        useadvancedsteepalgorithm = true,--set false for a less extreme track
        alldownhill = false,
		calculate_antijumps_and_antitraffic = false
		--end track generation settings
		
        --trafficcompression=.5,
}
if oddNumLanes then
	SetSkinProperties{
		lanedividers={-7.5,-4.5,-1.5,1.5,4.5,7.5},
		shoulderlines={-11.0,11.0},
		trackwidth = 11.5
	}
else
	SetSkinProperties{
		lanedividers={-6,-3,0,3,6},
		shoulderlines={-11.0,11.0},
		trackwidth = 11.5
	}
end

function deepcopy(orig) -- a pretty standard lua function for making a copy of a table
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

if not players then --create the players if they haven't been created yet
	players = {}
	players[1]={
		score=0,
		prevInput={},
		iPrevRing=0,
		hasFinishedScoringPrevRing=false,
		uniqueName = "Right",
		num=1,
		prevFirstBlockCollisionTested = 1,
		pos = {0,0,1.5},
		posCosmetic = {0,0,1.5},
		controller = "mouse",
		points = 0, -- used for accumulating points this player earns at each match collection. temp var
		lane = 0
	}
end

function OnTrackCreated(theTrack)--track is created before the traffic
	track = theTrack --store a global copy of the track to maybe use later
	-- when you return a track table from this function the game will read and apply any changes you made
end

lanespace = 3
half_lanespace = 1.5

blocks = blocks or {}
blockNodes = blockNodes or {}
blockOffsets = blockOffsets or {}
blockColors = blockColors or {}

function OnTrafficCreated(theTraffic)
	half_lanespace = lanespace / 2

	traffic = theTraffic

    for i = 1, #traffic do
    	local lane = 0
    	if oddNumLanes then
    		lane = math.random(-halfLanes,halfLanes)
    	else
    		while lane == 0 do -- with an even lane count there is no center lane, so loop until we get a nonzero lane
    			lane = math.random(-halfLanes,halfLanes)
    		end
    	end
    	traffic[i].lane = lane

    	local strafe = lane*lanespace
    	if not oddNumLanes then
	    	if strafe < 0 then strafe = strafe + half_lanespace
	    	else strafe = strafe - half_lanespace end
	    end

    	traffic[i].strafe = strafe
    	local offset = {strafe,0,0}
		local block = {}
		block.lane = lane
		block.hidden = false
		block.collisiontestcount = 0
		block.tested = {}
		for j=1,#players do
			block.tested[j] = false
		end
		block.type = traffic[i].type
		blocks[#blocks+1]=block
		blockNodes[#blockNodes+1] = traffic[i].impactnode
		blockOffsets[#blockOffsets+1] = offset
		blockColors[#blockColors+1] = track[traffic[i].impactnode].color
--    	end
    end

    return traffic -- when you return a traffic table from this function the game will read and apply any changes you made
end

function OnSkinLoaded()-- called after OnTrafficCreated. The skin script has loaded content.
	CreateClone{name=players[1].uniqueName, prefabName="Vehicle", attachToTrackWithNodeOffset=-1, transform={pos=players[1].pos}}

	SetPuzzle{trackoffset=-.25}

	HideBuiltinPlayerObjects() -- hide the game-controlled vehicle since we're using script-controlled vehicles instead. Also hides the game-controlled surfer

	SetScoreboardNote{text="100% - Legend"}
	SetGlobalScore{score=score}

	SetCamera{ -- calling this function (even just once) overrides the camera settings from the skin script
		nearcam={
			pos={0,4,-3.50475},
			rot={38,0,0},
			strafiness = 0
		},
		farcam={
			pos={0,12.8,-3.50475},
			rot={41,0,0},
			strafiness = 0
		}
	}
end

score = 0 --the global score shared by all players co-operatively
numBlocks = 0

function OnPuzzleCollecting()
--Do nothing
	-- local points = 0

	-- local puzzle = GetPuzzle()
	-- local matchSize = puzzle["matchedcellscount"]
	-- if matchSize < 1 then -- no matches collected. Drop chain bonus here

	-- else
		-- local cells = puzzle["cells"]
		-- for colnum=1,#cells do
			-- local col = cells[colnum]
			-- for rownum=1,#col do
				-- local cell = col[rownum]
				-- if cell["matched"] then
					-- local cellPoints = 10 * ((cell["type"]+1) * cell["matchsize"])
					-- points = points + cellPoints
				-- end
			-- end
		-- end

		-- score = score + points -- add the shared points earned from this collection batch
		-- SetGlobalScore{score=score,showdelta=true}
	-- end
	-- players[1].points = score
end

iCurrentRing = 0 --Update function keeps this current
blocksToHide = {}
legendary = true
stealthy = true

function Collide(player, tracklocation)
	local strafe = player.pos[1]
	local playerLane = 0;

	local absStrafe = math.abs(strafe)

	if oddNumLanes then
		for i=2,0,-1 do
			if absStrafe > ((lanespace * i) + half_lanespace) then
				playerLane = i+1
				break
			end
		end
	else
		if absStrafe > lanespace * 2 then playerLane = 3 --a player in lane 3 is on the shoulder and will not collide with any blocks
		elseif absStrafe > lanespace * 1 then playerLane = 2
		else playerLane = 1 end
	end

	if strafe < 0 then
		playerLane = -playerLane
	end
	
	local collisionTolerenceAhead = .1
	local collisionToleranceBehind_colors = .9

	local maxRing = iCurrentRing + 20
	local foundFirst = false
	for i=player.prevFirstBlockCollisionTested,#blockNodes do
		if not blocks[i].tested[player.num] then
			if blockNodes[i] <= maxRing then
				if not foundFirst then
					player.prevFirstBlockCollisionTested = i
					foundFirst = true
				end
				
				local allowCollision = false

				local collisionToleranceBehind = (blocks[i].type == 5) and collisionToleranceBehind_greys or collisionToleranceBehind_colors

				if blockNodes[i] < (tracklocation - collisionToleranceBehind) then
					if blocks[i].collisiontestcount < 1 then
						allowCollision = true -- make sure each block is allowed at least one collision test, no matter how far behind the impact node it is now
					end
					blocks[i].irrelevant = true
				end

				if (blockNodes[i] <= (tracklocation + collisionTolerenceAhead)) and (blockNodes[i] >= (tracklocation - collisionToleranceBehind)) then
					allowCollision = true
				end

				if allowCollision then
					blocks[i].collisiontestcount = blocks[i].collisiontestcount + 1
					if not blocks[i].hidden then
						numBlocks = numBlocks + 1
						if blocks[i].lane == playerLane then
							blocksToHide[#blocksToHide+1] = i
							blocks[i].hidden = true

							local blockOffset = blockOffsets[i]
							
							score = score + 1
							SetGlobalScore{score=score,showdelta=false}
						else
							if legendary then
								legendary = false
							end
						end
						
						local scoreBoardNote = ""
						
						if legendary then
							scoreBoardNote = "Legend"
						else 
							local hitRate = math.floor((score / numBlocks) * 100 + 0.5);
							scoreBoardNote = hitRate.."%"
						end
						
						SetScoreboardNote{text=scoreBoardNote}
						SendCommand{command="HoverUp"}
					end
					blocks[i].tested[player.num] = true
				end
			else
				break --stop the loop once we get to a block way past the player
			end
			--end
		end
	end
	
end

mouseSpeed = .42
cosmeticStrafeSpeed = 15
maxStrafe = halfLanes * 3
if not oddNumLanes then
	maxStrafe = maxStrafe - 1.5
end

function UpdatePlayer(player, tracklocation, input, dt, player1_rightStick, keys)
	--print("Vertical:"..input["Vertical"])
	local mouseInput = input["mouse"]
	local mouseHorizontal = mouseInput["x"]
	local keyHorizontal = input["Horizontal"]
	local prevKeyHorizontal = player.prevInput["Horizontal"]

	if(player.controller=="mouse") then
		if keyHorizontal ~= 0 then
			player.controller = "key"
		end
	elseif mouseHorizontal~=0 then
		if player.num==1 then -- only player1 has the option of mouse control
			player.controller = "mouse"
		end
	end

	if player.controller=="mouse" then
		if dt>0 then --don't move when the game is paused
			player.pos[1] = math.min(maxStrafe, math.max(-maxStrafe, player.pos[1] + mouseHorizontal * mouseSpeed))
		end

		player.posCosmetic[1] = player.pos[1]
	else --key mode (keyboard or gamepad)

		if keyHorizontal > 0.5 and prevKeyHorizontal <= 0.5 then 
			player.lane = player.lane + 1
		elseif keyHorizontal < -0.5 and prevKeyHorizontal >= -0.5 then
			player.lane = player.lane - 1 
		end

		if player.lane > halfLanes then
			player.lane = halfLanes
		elseif player.lane < -halfLanes then
			player.lane = -halfLanes
		elseif player.lane == 0 and not oddNumLanes then
			if keyHorizontal > 0.5 and prevKeyHorizontal <= 0.5 then 
				player.lane = player.lane + 1
			elseif keyHorizontal < -0.5 and prevKeyHorizontal >= -0.5 then
				player.lane = player.lane - 1 
			end
		end

		player.pos[1] = lanespace * player.lane
		if not oddNumLanes then
    		if player.pos[1] < 0 then player.pos[1] = player.pos[1] + half_lanespace
    		else player.pos[1] = player.pos[1] - half_lanespace end
    	end

		player.posCosmetic[1] = player.posCosmetic[1] + cosmeticStrafeSpeed * dt * (player.pos[1] - player.posCosmetic[1])
	end

	SendCommand{command="SetTransform", name=player.uniqueName, param={pos=player.posCosmetic}}

	Collide(player, tracklocation)

	player.prevInput = input
end

percentPuzzleFilled = 0
quarterSecondCounter = 0
function UpdateEachQuarterSecond() -- for things that need to run regularly, but not every frame
	-- local puzzle = GetPuzzle()
	-- local cells = puzzle["cells"]
	-- local numFilled = 0
	-- local numCells = 0
	-- for colnum=1,#cells do
		-- local col = cells[colnum]
		-- for rownum=1,#col do
			-- numCells = numCells + 1
			-- local cell = col[rownum]
			-- if cell.type >=0 then
				-- numFilled = numFilled + 1
			-- end
		-- end
	-- end

	-- percentPuzzleFilled = numFilled / numCells
end

function Update(dt, tracklocation, playerstrafe, input) --called every frame
	iCurrentRing = math.floor(tracklocation)
	local playersInput = input["players"]

	blocksToHide = {}

	local player1_input = playersInput[1]
	local player1_rightStick = player1_input["Horizontal2"]

	for i=1,#players do
		UpdatePlayer(players[i], tracklocation, playersInput[i], dt, player1_rightStick, input["keyboard"])
	end

	if #blocksToHide > 0 then
		HideTraffic(blocksToHide)
		local hiddenBlockID = blocksToHide[1]
		local blockType = blocks[hiddenBlockID].type
		FlashAirDebris{colorID=fif(blockType>100, 5, blockType), duration = fif(blockType>100, 0.5, .05), sizescaler = fif(blockType>100, 5, 2)}
	end

	quarterSecondCounter = quarterSecondCounter + dt
	if quarterSecondCounter>.25 then
		quarterSecondCounter = 0 -- quarterSecondCounter - .25
		-- UpdateEachQuarterSecond()
	end
end

function GetPercentPuzzleFilled(countMatchedCellsAsEmpty)
	local puzzle = GetPuzzle()
	local cells = puzzle["cells"]
	local numFilled = 0
	local numCells = 0;
	for colnum=1,#cells do
		local col = cells[colnum]
		for rownum=1,#col do
			numCells = numCells + 1
			local cell = col[rownum]
			if cell.type >=0 then
				if not (countMatchedCellsAsEmpty and cell["matched"]) then
					numFilled = numFilled + 1
				end
			end
		end
	end

	return numFilled / numCells
end

function OnRequestFinalScoring()
	local legendBonus = 0
	if legendary then legendBonus = 9000 end
	
	local hitRate = math.floor((score / numBlocks) * 100 + 0.5)
	
	return {
		rawscore = score,
		bonuses = {
			"Legend Bonus: "..legendBonus,
			"Hit Rate: "..hitRate.."%"
		},
		finalscore = score + legendBonus
	}
end
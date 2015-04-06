--[[========================================================================\\
  ||  EZTCP (v1.0.0) - A library to simplify TCP networking.                ||
  ||  Copyright (C) 2015 Niko Geil.                                         ||
  ||                                                                        ||
  ||  This program is free software: you can redistribute it and/or modify  ||
  ||  it under the terms of the GNU General Public License as published by  ||
  ||  the Free Software Foundation, either version 3 of the License, or     ||
  ||  (at your option) any later version.                                   ||
  ||                                                                        ||
  ||  This program is distributed in the hope that it will be useful,       ||
  ||  but WITHOUT ANY WARRANTY; without even the implied warranty of        ||
  ||  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the          ||
  ||  GNU General Public License for more details.                          ||
  ||                                                                        ||
  ||  You should have received a copy of the GNU General Public License     ||
  ||  along with this program. If not, see <http://www.gnu.org/licenses/>.  ||
  \\========================================================================]]

local eztcp = {}
eztcp.create = {}
eztcp.send = {}

-- Create an empty set for the server and client objects.
function eztcp.create.set()
	local set = {}

	setmetatable(set, {
		__index = {
			insert = function (set, client)		-- Insert object into set.
				table.insert(set, client)
			end,
			remove = function (set, client)		-- Remove object from set.
				for k, v in pairs(set) do
					if v == client then
						table.remove(set, k)
						break
					end
				end
			end,
		}
	})

	return set
end

-- Send a raw message (appending a newline).
function eztcp.send.raw(client, line)
	local bytes, err = client:send(line .. "\n")		-- Get bytes or err.
	return bytes, err
end

-- Send a raw message.
function eztcp.send.realRaw(client, line)
	local bytes, err = client:send(line)		-- Get bytes or err.
	return bytes, err
end

-- Create a server object.
function eztcp.create.server(bindTo, bindToPort, set, timeout)
	local server = socket.bind(bindTo, bindToPort)	-- Create the server.

	if set then				-- If we got a set, then...
		set:insert(server)	-- Insert the server into it.
	end

	if timeout and type(timeout) == "number" then	-- Verify timeout.
		server:settimeout(timeout)		-- Set timeout if we got it.
	end

	return server, set
end

--[[
  ||  Process returns:
  ||    client object or nil, set, message or status code or nil, error or nil
  ||  Status codes:
  ||    0 - Client connected.
  ||    1 - Client disconnected.
  ||    2 - Client timed out.
  ]]

-- Process the set. This is usually in a loop. Note that this function requires
-- set[1] to be the server object. This will not work if it is not.
function eztcp.process(set)
	local reading, _, err = socket.select(set)
	for _, object in ipairs(reading) do
		if object == set[1] then
			local client, err = object:accept()		-- Create a client object.
			if client then
				set:insert(client)		-- Insert client into set.
				return client, set, 0, nil
			else
				return nil, set, nil, "Could not create new client: " .. err
			end
		else
			local line, err = object:receive()
			if err and err == "closed" then
				set:remove(object)		-- If client closed their connection.
				object:close()			-- Closed the connection.
				return object, set, 1, nil
			elseif err and err == "timeout" then
				set:remove(object)		-- If client timed out.
				object:close()			-- Close the connection.
				return object, set, 2, nil
			elseif err then
				set:remove(object)		-- If an error occurred.
				object:close()			-- Close the connection.
				return object, set, nil, err
			else		-- If we got here, we received a message successfully.
				return object, set, line, nil
			end
		end
	end
end

return eztcp
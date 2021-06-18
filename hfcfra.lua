-- Inofficial hfc frankfurt Extension (https://www.hfc-frankfurt.de) for MoneyMoney
-- Fetches flight balance from hfc-frankfurt and returns them
--
-- Copyright (c) 2021 Nima Barraci
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

WebBanking{version     = 1.00,
           url         = "https://www.hfc-frankfurt.de",
           services    = {"Hanseatischer Fliegerclub Frankfurt"},
           description = "Kontostand Hanseatischer Fliegerclub Frankfurt"}

function SupportsBank (protocol, bankCode)
  return protocol == ProtocolWebBanking and bankCode == "Hanseatischer Fliegerclub Frankfurt"
end

-- State
local connection = Connection()
local html
local _username


function InitializeSession (protocol, bankCode, username, customer, password)

    -- Fetch login page.
    connection.language = "de-de"
    html = HTML(connection:get("https://www.hfc-frankfurt.de/index.php?op=login"))

        _username = username

    html:xpath("//input[@name='userid']"):attr("value", username)
    html:xpath("//input[@name='password']"):attr("value", password)

    html = HTML(connection:request(html:xpath("//input[@type='submit']"):click()))

    if html:xpath("//a[@href='/index.php?op=logout']"):length() == 0 then
            MM.printStatus("Login Failed")
      return LoginFailed
    end
end

function ListAccounts (knownAccounts)
  -- Return array of accounts.
  local account = {
    name = "HFC Frankfurt",
    owner = _username,
    accountNumber = _username,
    bankCode = "",
    currency = "EUR",
    type = AccountTypeOther
  }
  return {account}
end

function RefreshAccount (account, since)
  -- Return balance and array of transactions.
  local _transactions = {}

  html = HTML(connection:get("https://www.hfc-frankfurt.de/account.php"))
  local _balanceTable = html:xpath("//table[@class='manager rwd']")

  -- Parse each transaction
  local _transactionsRows = _balanceTable:xpath("(//table//tbody//tr)")

  for i=1,_transactionsRows:length() do
          local _currentRow = _transactionsRows:get(i)

          local _leadElement = _currentRow:children():get(1):text()


           if (_leadElement == 'V' or _leadElement == 'U' or _leadElement == 'L' or _leadElement == 'N' or _leadElement == 'J') then

                  _transactions[#_transactions+1] = {

                     bookingDate = getPOSIXdate(_currentRow:children():get(2):text()),

                     purpose = getTransactionEntry(_currentRow:children():get(1):text(),
                                                                                    _currentRow:children():get(2):text(),
                                                                                    _currentRow:children():get(3):text(),
                                                                                      _currentRow:children():get(4):text(),
                                                                                   _currentRow:children():get(5):text(),
                                                                                   _currentRow:children():get(6):text(),
                                                                                   _currentRow:children():get(7):text(),
                                                                                   _currentRow:children():get(8):text(),
                                                                                  _currentRow:children():get(9):text(),
                                                                                  _currentRow:children():get(10):text()),
                     amount = toNumber(_currentRow:children():get(11):text())
                  }

           end
  end
  -- End transaction


  -- Begin balance
  local _balance = _balanceTable:xpath("(//table//td[@data-header='Kontostand'])"):text()
  -- End balance

  return {balance=toNumber(_balance), transactions=_transactions}
end

function EndSession ()
  -- Logout.
end

-- Helper
function getTransactionEntry(type, date, acreg, from, to, flighttime, flightCosts, landings, landingsCost, comments)
        local _workstring

        if (type== 'V') then
                _workstring = "Vortrag\n" .. "Comments: " .. comments
        elseif (type == 'U') then
                _workstring = "Überweisung\n" .. "Comments: " .. comments
        elseif (type == 'L') then
                _workstring = "Schulungsflug\n" ..  "AC: " .. string.upper(acreg) .. " " ..
                                        "From: " .. string.upper(from) .. " " ..
                                        "To: " .. string.upper(to) .. " " ..
                                        "Date: " .. date .. " " ..
                                        "Flight Time: " .. flighttime .. " " ..
                                        "Flight Cost: " .. flightCosts .. " " ..
                                        "Landings: " .. landings .. " " ..
                                        "Landings Cost: " .. landingsCost .. " "
        elseif (type == 'J') then
                _workstring = "Jahresbeitrag\n" .. "Comments: " .. comments
        elseif (type == 'N') then
                _workstring = "Flug\n" .. "AC: " .. string.upper(acreg) .. " " ..
                                        "From: " .. string.upper(from) .. " " ..
                                        "To: " .. string.upper(to) .. " " ..
                                        "Date: " .. date .. " " ..
                                        "Flight Time: " .. flighttime .. " " ..
                                        "Flight Cost: " .. flightCosts .. " " ..
                                        "Landings: " .. landings .. " " ..
                                        "Landings Cost: " .. landingsCost .. " "
        else
                _workstring = "Sonstiges\n" .. "Comments: " .. comments
        end

        return _workstring
end

function getPOSIXdate(str)
        local _splits = mysplit(str,"-")


        return os.time{day=_splits[3], year=_splits[1], month=_splits[2]}
end

function mysplit (inputstr, sep)
        if sep == nil then
                sep = "%s"
        end
        local t={}
        for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
                table.insert(t, str)
        end
        return t
end

function toNumber(str)

        local _workstring = trim1(str)
        local _mult = 1

        _workstring = string.sub(_workstring,0,string.len(_workstring))

        if string.match(_workstring, "-") then
                _mult = -1
        end


        _workstring = string.match(_workstring,'%f[%d]%d[,.%d]*%f[%D]')

        _workstring = string.gsub(_workstring,",",".")

        local _number = _workstring * _mult
        return _number
end

function trim1(s)
   return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- originally from http://stackoverflow.com/questions/6075262/lua-table-tostringtablename-and-table-fromstringstringtable-functions
-- modified fixed a serialization issue with invalid name. and wrap with 2 functions to serialize / deserialize

function tableToString(table)
        return "return"..serializeTable(table)
end

function stringToTable(str)
        local f = loadstring(str)
        return f()
end

function serializeTable(val, name, skipnewlines, depth)
    skipnewlines = skipnewlines or false
    depth = depth or 0

    local tmp = string.rep(" ", depth)
    if name then
            if not string.match(name, '^[a-zA-z_][a-zA-Z0-9_]*$') then
                    name = string.gsub(name, "'", "\\'")
                    name = "['".. name .. "']"
            end
            tmp = tmp .. name .. " = "
     end

    if type(val) == "table" then
        tmp = tmp .. "{" .. (not skipnewlines and "\n" or "")

        for k, v in pairs(val) do
            tmp =  tmp .. serializeTable(v, k, skipnewlines, depth + 1) .. "," .. (not skipnewlines and "\n" or "")
        end

        tmp = tmp .. string.rep(" ", depth) .. "}"
    elseif type(val) == "number" then
        tmp = tmp .. tostring(val)
    elseif type(val) == "string" then
        tmp = tmp .. string.format("%q", val)
    elseif type(val) == "boolean" then
        tmp = tmp .. (val and "true" or "false")
    else
        tmp = tmp .. "\"[inserializeable datatype:" .. type(val) .. "]\""
    end

    return tmp
end

-- SIGNATURE: MCwCFEs1QAdLuu6WYxsVnnVRkYCOqyKoAhQKoEnYY2FuPWKAlMC3AOPyYX4RXA==

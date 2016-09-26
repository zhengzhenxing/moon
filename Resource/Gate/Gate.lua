package.path    = 'Base/?.lua;Gate/?.lua;Login/?.lua;'
package.cpath 	= 'Base/?.so;Base/?.dll;./?.so;./?.dll;'

require("functions")
require("Log")

local protobuf  = require "protobuf"
local Module    = require("Module")
local Network   = require("Network")
local Connects  = require("Connect")
local MsgID     = require("MsgID")
local GateHandler = require("GateHandler")
local GateLoginHandler = require("GateLoginHandler")
local LoginDatas = require("LoginDatas")

local Gate = class("Gate", Module)

function Gate:ctor()
    Gate.super.ctor(self)

    self.connects = nil
    self.net = nil
    self.gateLoginHandler = nil

    self.worldModule = 0
    self.loginModule = 0
    self.ID          = 0

    Log.Trace("ctor Gate")

    addr = io.open("MsgLogin.pb","rb")
    buffer = addr:read "*a"
    addr:close()
    protobuf.register(buffer)

end

function Gate:Init(config)
    self.ID = Gate.super.GetID(self)
    Gate.super.SetGateModule(self,self.ID)

    self.net = Network.new()
    self.net:Init(1)
    self.net:Listen("127.0.0.1", "11111")
    self.net:SetCB(handler(self,self.OnNetMessage))
    Gate.super.AddComponent(self, "Network", self.net)

    Gate.super.AddComponent(self,"Connects", Connects.new())
    Gate.super.AddComponent(self,"GateHandler", GateHandler.new())
    Gate.super.AddComponent(self,"GateLoginHandler",GateLoginHandler.new())
    Gate.super.AddComponent(self,"LoginDatas",LoginDatas.new())

    self.connects = Gate.super.GetComponent(self,"Connects")
    self.gateLoginHandler = Gate.super.GetComponent(self,"GateLoginHandler")

    Log.Trace("Gate Module Init: %s",config)
end

function Gate:OnNetMessage(msg)
    Gate.super.Send(self,self.ID,msg,0,msg:GetType())
end

function Gate:OnMessage(msg)
    if msg:GetType() == EMessageType.NetworkConnect then
        self:ClientConnect(msg)
    elseif msg:GetType() == EMessageType.NetworkData then
        self:ClientData(msg)
    elseif msg:GetType() == EMessageType.NetworkClose then
        self:ClientClose(msg)
    elseif msg:GetType() == EMessageType.ModuleData then
        self:ModuleData(msg)
    elseif msg:GetType() == EMessageType.ToClient then
        self:ToClientData(msg)
    end
end

function Gate:ClientConnect(msg)
    local br = MessageReader.new(msg)
    Log.ConsoleTrace("CLIENT CONNECT: %s",br:ReadString())
end

function Gate:ClientData(msg)
    if Gate.super.DispatchMessage(self, msg) then
        return
    end

    local sessionID = msg:GetSessionID()
    local conn = self.connects:Find(sessionID)
    if nil == conn then
        Log.ConsoleWarn("Illegal Msg: client not connected.")
        return
    end

    local br = MessageReader.new(msg)

    local msgID = br:ReadInt16()

    if msgID > MsgID.MSG_MUST_HAVE_PLAYERID then
        Log.ConsoleWarn("Illegal Msg: client not login msgID[%u].",msgID)
        return
    end

    if conn.playerID ~= 0 then
        msg:SetPlayerID(conn.playerID)
    elseif conn.accountID ~=0 then
        msg:SetAccountID(conn.accountID)
    end

    if conn.sceneID ~= 0 then

    else
        if self.worldModule == nil then
            self.worldModule = Gate.super.GetOtherModule("World")
            assert(nil ~= self.worldModule)
        end
    end
end

function Gate:ClientClose(msg)
    local br = MessageReader.new(msg)
    Log.ConsoleTrace("CLIENT CLOSE: %s",br:ReadString())

    local sessionID = msg:GetSessionID()

    self.gateLoginHandler:OnSessionClose(sessionID)

    local conn = self.connects:Find(sessionID)
    if nil == conn then
        return
    end

    Gate.super.OnClientClose(self,conn.accountID, conn.playerID)

    if self.connects:Remove(sessionID) then

    else
        assert(0)
    end
end

function Gate:ModuleData(msg)
    Gate.super.DispatchMessage(self, msg)
end

function Gate:ToClientData(msg)
    local sessionID = 0
    if msg:HasAccountID() then
        local conn = self.connexts.FindByAccount(msg:GetAccountID())
        sessionID = conn.sessionID
    elseif msg:HasPlayerID() then
        local conn = self.connexts.FindByPlayer(msg:GetPlayerID())
        sessionID = conn.sessionID
    end

    if 0 == sessionID then
        return
    end

    self.net:SendNetMessage(sessionID, msg)
end

function  Gate:SendNetMessage(sessionID,msg)
    self.net:Send(sessionID,msg)
end

function Gate:SetWorldModule(moduleid)
    self.worldModule = moduleid
end

function Gate:GetWorldModule()
    return self.worldModule
end


function Gate:SetLoginModule(moduleid)
    self.loginModule = moduleid
end

function Gate:GetLoginModule()
    return self.loginModule
end

return Gate

-- Shared wire contract for MFS weapon-light multiplayer state.
--
-- Only state transitions cross the network. Player position and facing already
-- belong to Project Zomboid's normal player replication and are deliberately
-- not duplicated here.

MFSWeaponLightNetwork = MFSWeaponLightNetwork or {}

local Network = MFSWeaponLightNetwork

Network.VERSION = "1.0.0-rc1"
Network.MODULE = "MFSWeaponLight"
Network.SET_STATE = "SetState"
Network.STATE = "State"
Network.REQUEST_ALL = "RequestAll"
Network.SNAPSHOT = "Snapshot"

return Network

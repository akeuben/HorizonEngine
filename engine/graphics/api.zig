var api: API = API.NONE;
var api_locked: bool = false;

pub const API = enum { OPEN_GL, VULKAN, NONE };

pub const APIError = error{ API_LOCKED, API_NOT_IMPLEMENTED };

pub fn get_api() API {
    return api;
}

pub fn set_api(new_api: API) !void {
    if (api_locked) {
        return APIError.API_LOCKED;
    }
    api = new_api;
}

pub fn lock_api() void {
    api_locked = true;
}

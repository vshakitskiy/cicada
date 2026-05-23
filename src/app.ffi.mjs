import { Result$Ok, Result$Error } from "./gleam.mjs"

export function now() {
    return Date.now()
}

export function request_animation_frame(callback) {
    requestAnimationFrame(callback)
}

export function set_item(key, value) {
    localStorage.setItem(key, value)
}

export function get_item(key) {
    const value = localStorage.getItem(key)
    if (value === null) {
        return Result$Error(undefined)
    }

    return Result$Ok(value)
}

export function remove_item(key) {
    localStorage.removeItem(key)
}

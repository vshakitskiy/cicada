import gleam/int
import gleam/string
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html

pub fn main() -> Nil {
  let app = lustre.application(init:, update:, view:)
  let assert Ok(_runtime) = lustre.start(app, "#app", Nil)

  Nil
}

type Model {
  Model(start_time: Int, current_time: Int)
}

fn init(_nil) -> #(Model, effect.Effect(Message)) {
  let time = now()
  #(Model(start_time: time, current_time: time), tick())
}

@external(javascript, "./app.ffi.mjs", "now")
fn now() -> Int {
  0
}

type Message {
  Ticked(current_time: Int)
}

fn tick() -> effect.Effect(Message) {
  effect.from(fn(dispatch) {
    use <- request_animation_frame
    dispatch(Ticked(current_time: now()))
  })
}

@external(javascript, "./app.ffi.mjs", "request_animation_frame")
fn request_animation_frame(_callback: fn() -> a) -> Nil {
  Nil
}

fn update(model: Model, message: Message) -> #(Model, effect.Effect(Message)) {
  case message {
    Ticked(current_time) -> #(Model(..model, current_time:), tick())
  }
}

fn view(model: Model) -> element.Element(Message) {
  let elapsed = model.current_time - model.start_time
  let timer = parse_milliseconds(elapsed)

  html.main(
    [
      attribute.class(
        "min-h-dvh flex font-bold items-center justify-center px-3 select-none",
      ),
    ],
    [
      html.p([attribute.class("text-3xl")], [
        element.text(timer.hours),
        element.text(":"),
        element.text(timer.minutes),
        element.text(":"),
        element.text(timer.seconds),
        element.text(":"),
        element.text(timer.milliseconds),
      ]),
    ],
  )
}

type Timer {
  Timer(milliseconds: String, seconds: String, minutes: String, hours: String)
}

fn parse_milliseconds(milliseconds: Int) {
  let seconds = milliseconds / 1000
  let minutes = seconds / 60
  let hours = minutes / 60

  Timer(
    milliseconds: int.to_string(milliseconds % 1000)
      |> string.pad_start(to: 3, with: "0"),
    seconds: int.to_string(seconds % 60) |> string.pad_start(to: 2, with: "0"),
    minutes: int.to_string(minutes % 60) |> string.pad_start(to: 2, with: "0"),
    hours: int.to_string(hours) |> string.pad_start(to: 2, with: "0"),
  )
}

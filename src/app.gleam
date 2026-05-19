import app/icon
import gleam/int
import gleam/pair
import gleam/string
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/event

pub fn main() -> Nil {
  let app = lustre.application(init:, update:, view:)
  let assert Ok(_runtime) = lustre.start(app, "#app", Nil)

  Nil
}

type Model {
  Model(start_time: Int, current_time: Int, started: Bool, paused: Bool)
}

fn init(_nil) -> #(Model, effect.Effect(Message)) {
  Model(start_time: 0, current_time: 0, started: False, paused: False)
  |> pair.new(effect.none())
}

@external(javascript, "./app.ffi.mjs", "now")
fn now() -> Int {
  0
}

type Message {
  TimerStarted
  TimerPauseToggled
  TimerReset
  Ticked(date: Int)
}

fn tick() -> effect.Effect(Message) {
  effect.from(fn(dispatch) {
    use <- request_animation_frame
    dispatch(Ticked(date: now()))
  })
}

@external(javascript, "./app.ffi.mjs", "request_animation_frame")
fn request_animation_frame(_callback: fn() -> a) -> Nil {
  Nil
}

fn update(model: Model, message: Message) -> #(Model, effect.Effect(Message)) {
  case message {
    TimerStarted -> {
      let date = now()
      Model(..model, start_time: date, current_time: date, started: True)
      |> pair.new(tick())
    }
    TimerPauseToggled -> {
      let date = now()
      case model.paused {
        False ->
          Model(..model, current_time: date, paused: True)
          |> pair.new(effect.none())

        True -> {
          let start_time = model.start_time + date - model.current_time
          Model(..model, start_time:, current_time: date, paused: False)
          |> pair.new(tick())
        }
      }
    }
    TimerReset -> #(
      Model(start_time: 0, current_time: 0, started: False, paused: False),
      effect.none(),
    )

    Ticked(date) if model.started && !model.paused ->
      Model(..model, current_time: date) |> pair.new(tick())
    Ticked(_date) -> #(model, effect.none())
  }
}

fn view(model: Model) -> element.Element(Message) {
  html.main(
    [
      attribute.class(
        "min-h-dvh flex font-bold items-center justify-center px-3 select-none",
      ),
    ],
    [html.div([attribute.class("w-full flex flex-col")], view_timer(model))],
  )
}

fn view_timer(model: Model) {
  let elapsed = model.current_time - model.start_time
  let timer = parse_milliseconds(elapsed)

  [
    html.p([attribute.class("text-3xl text-center")], [
      element.text(timer.hours),
      element.text(":"),
      element.text(timer.minutes),
      element.text(":"),
      element.text(timer.seconds),
      element.text(":"),
      element.text(timer.milliseconds),
    ]),

    case model.started {
      False ->
        html.button(
          [
            attribute.class("bg-stone-50 cursor-pointer w-full rounded-sm mt-3"),
            event.on_click(TimerStarted),
          ],
          [
            icon.play("text-stone-950 size-7 mx-auto"),
          ],
        )
      True ->
        html.div([attribute.class("mt-3 flex gap-1")], [
          html.button(
            [
              attribute.class("bg-stone-50 cursor-pointer w-full rounded-sm"),
              event.on_click(TimerPauseToggled),
            ],
            [
              case model.paused {
                True -> icon.play("text-stone-950 size-7 mx-auto")
                False -> icon.stop("text-stone-950 size-7 mx-auto")
              },
            ],
          ),
          html.button(
            [
              attribute.class(
                "bg-stone-50 cursor-pointer w-full py-1 rounded-sm",
              ),
              event.on_click(TimerReset),
            ],
            [
              icon.reset("text-stone-950 size-5 mx-auto"),
            ],
          ),
        ])
    },
  ]
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

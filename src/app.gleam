import app/component
import app/icon
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/pair
import gleam/string
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/element/keyed
import lustre/event

pub fn main() -> Nil {
  let app = lustre.application(init:, update:, view:)
  let assert Ok(_runtime) = lustre.start(app, "#app", Nil)

  Nil
}

type Model {
  Idle
  Timer(
    start_time: Int,
    current_time: Int,
    paused: Bool,
    checkpoints: List(Checkpoint),
  )
}

type Store {
  Store(elapsed: Int, paused: Bool, checkpoints: List(Checkpoint))
}

fn store_to_json(store: Store) -> json.Json {
  let Store(elapsed:, paused:, checkpoints:) = store
  json.object([
    #("elapsed", json.int(elapsed)),
    #("paused", json.bool(paused)),
    #("checkpoints", json.array(checkpoints, checkpoint_to_json)),
  ])
}

fn store_decoder() -> decode.Decoder(Store) {
  use elapsed <- decode.field("elapsed", decode.int)
  use paused <- decode.field("paused", decode.bool)
  use checkpoints <- decode.field(
    "checkpoints",
    decode.list(checkpoint_decoder()),
  )

  decode.success(Store(elapsed:, paused:, checkpoints:))
}

fn persist(model: Model) -> Model {
  case model {
    Idle -> remove_item("store")
    Timer(start_time:, current_time:, paused:, checkpoints:) ->
      Store(elapsed: current_time - start_time, paused:, checkpoints:)
      |> store_to_json
      |> json.to_string
      |> set_item("store", _)
  }

  model
}

@external(javascript, "./app.ffi.mjs", "set_item")
fn set_item(_key: String, _value: String) -> Nil {
  Nil
}

@external(javascript, "./app.ffi.mjs", "get_item")
fn get_item(_key: String) -> Result(String, Nil) {
  Error(Nil)
}

@external(javascript, "./app.ffi.mjs", "remove_item")
fn remove_item(_key: String) -> Nil {
  Nil
}

type Checkpoint {
  Checkpoint(elapsed: Int, title: String)
}

fn checkpoint_to_json(checkpoint: Checkpoint) -> json.Json {
  let Checkpoint(elapsed:, title:) = checkpoint
  json.object([
    #("elapsed", json.int(elapsed)),
    #("title", json.string(title)),
  ])
}

fn checkpoint_decoder() -> decode.Decoder(Checkpoint) {
  use elapsed <- decode.field("elapsed", decode.int)
  use title <- decode.field("title", decode.string)
  decode.success(Checkpoint(elapsed:, title:))
}

fn init(_nil: a) -> #(Model, effect.Effect(Message)) {
  case get_item("store") {
    Ok(state) -> {
      case json.parse(from: state, using: store_decoder()) {
        Ok(Store(elapsed:, paused:, checkpoints:)) -> {
          let date = now()

          let model =
            Timer(
              start_time: date - elapsed,
              current_time: date,
              paused:,
              checkpoints:,
            )

          case paused {
            True -> #(model, effect.none())
            False -> #(model, tick())
          }
        }
        Error(_decode_error) -> #(Idle, effect.none())
      }
    }
    Error(Nil) -> #(Idle, effect.none())
  }
}

@external(javascript, "./app.ffi.mjs", "now")
fn now() -> Int {
  0
}

type Message {
  TimerStarted
  TimerPauseToggled
  TimerReset
  CheckpointCaptured
  CheckpointTitleUpdated(index: Int, title: String)
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
  case model, message {
    Idle, TimerStarted -> {
      let date = now()

      Timer(
        start_time: date,
        current_time: date,
        paused: False,
        checkpoints: [],
      )
      |> persist
      |> pair.new(tick())
    }
    Timer(..), TimerStarted -> panic as "unreachable"

    Timer(paused:, start_time:, current_time:, ..), TimerPauseToggled -> {
      let date = now()

      case paused {
        False ->
          Timer(..model, current_time: date, paused: True)
          |> persist
          |> pair.new(effect.none())

        True -> {
          let start_time = start_time + date - current_time

          Timer(..model, start_time:, current_time: date, paused: False)
          |> persist
          |> pair.new(tick())
        }
      }
    }
    Idle, TimerPauseToggled -> panic as "unreachable"

    Timer(..), TimerReset -> #(persist(Idle), effect.none())
    Idle, TimerReset -> panic as "unreachable"

    Timer(start_time:, current_time:, checkpoints:, ..), CheckpointCaptured -> {
      let elapsed = current_time - start_time
      let next_id = list.length(checkpoints) + 1

      let title =
        "lap "
        <> { int.to_string(next_id) |> string.pad_start(to: 2, with: "0") }

      Timer(..model, checkpoints: [Checkpoint(elapsed:, title:), ..checkpoints])
      |> persist
      |> pair.new(effect.none())
    }
    Idle, CheckpointCaptured -> panic as "unreachable"

    Timer(checkpoints:, ..), CheckpointTitleUpdated(index:, title:) -> {
      let checkpoints =
        list.index_map(checkpoints, with: fn(checkpoint, current) {
          case current == index {
            True -> Checkpoint(..checkpoint, title:)
            False -> checkpoint
          }
        })

      Timer(..model, checkpoints:)
      |> persist
      |> pair.new(effect.none())
    }
    Idle, CheckpointTitleUpdated(..) -> panic as "unreachable"

    Timer(paused: False, ..), Ticked(date) ->
      Timer(..model, current_time: date) |> persist |> pair.new(tick())
    Timer(paused: True, ..), Ticked(..) -> #(model, effect.none())
    Idle, Ticked(..) -> panic as "unreachable"
  }
}

fn view(model: Model) -> element.Element(Message) {
  html.main(
    [
      attribute.class(
        "min-h-dvh flex flex-col font-bold items-center justify-start pt-[30vh] px-3",
      ),
    ],
    [
      html.div(
        [
          attribute.class(
            "w-full max-w-xs xs:max-w-md md:max-w-xl lg:max-w-3xl xl:max-w-4xl 2xl:max-w-5xl flex flex-col",
          ),
        ],
        view_timer(model),
      ),
    ],
  )
}

fn view_timer(model: Model) -> List(element.Element(Message)) {
  case model {
    Idle -> [
      view_time(0),
      component.button(on_click: TimerStarted, class: "mt-3", children: [
        icon.play("text-stone-950 size-7 mx-auto xs:size-10 2xl:size-12"),
      ]),
    ]
    Timer(start_time:, current_time:, paused:, checkpoints:) -> {
      let total_checkpoints = list.length(checkpoints)
      let checkpoints =
        list.index_map(checkpoints, fn(checkpoint, index) {
          #(
            "checkpoint@" <> int.to_string(index),
            view_checkpoint(total_checkpoints, index, checkpoint),
          )
        })

      [
        view_time(current_time - start_time),
        html.div([attribute.class("mt-3 flex gap-1 xs:gap-2")], [
          component.button(on_click: TimerPauseToggled, class: "", children: [
            case paused {
              True ->
                icon.play(
                  "text-stone-950 size-7 xs:size-10 2xl:size-12 mx-auto",
                )
              False ->
                icon.stop(
                  "text-stone-950 size-7 xs:size-10 2xl:size-12 mx-auto",
                )
            },
          ]),
          component.button(
            on_click: TimerReset,
            class: "py-1 xs:py-2",
            children: [
              icon.reset("text-stone-950 xs:size-6 2xl:size-8 size-5 mx-auto"),
            ],
          ),
        ]),
        component.button(
          on_click: CheckpointCaptured,
          class: "py-1 xs:py-2 mt-1 xs:mt-2",
          children: [
            icon.checkpoint(
              "text-stone-950 xs:size-6 2xl:size-8 size-5 mx-auto",
            ),
          ],
        ),
        html.hr([attribute.class("mt-2 w-full border-stone-500")]),
        keyed.ul(
          [
            attribute.class(
              "mt-2 max-h-48 overflow-y-auto scroll-smooth custom-scrollbar flex flex-col gap-1 pr-1",
            ),
          ],
          checkpoints,
        ),
      ]
    }
  }
}

fn view_time(elapsed: Int) -> element.Element(Message) {
  html.p(
    [
      attribute.class(
        "text-3xl xs:text-5xl md:text-6xl lg:text-7xl xl:text-8xl 2xl:text-9xl text-center select-none",
      ),
    ],
    [
      element.text(time_to_string(parse_milliseconds(elapsed))),
    ],
  )
}

fn view_checkpoint(
  total: Int,
  index: Int,
  checkpoint: Checkpoint,
) -> element.Element(Message) {
  html.li(
    [
      attribute.class(
        "flex justify-between w-full items-center py-2 px-1 border-b last:border-none gap-2 border-stone-800 text-stone-400 font-mono text-xs xs:text-base lg:text-lg 2xl:text-xl xs:py-3 xs:gap-3 lg:gap-4 2xl:gap-5",
      ),
    ],
    [
      html.span([attribute.class("text-stone-500 shrink-0")], [
        element.text("#"),
        element.text(
          int.to_string(total - index) |> string.pad_start(to: 2, with: "0"),
        ),
      ]),

      // this is a cursed small trick for auto-grow for textarea with CSS only
      //
      // There is also field-sizing property:
      // https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/field-sizing
      // Buuuut for the time of documenting, it is not supported on firefox yet;
      // In development, Firefox 152 with the release date of 2026-06-16
      html.div([attribute.class("grid grow")], [
        html.div(
          [
            attribute.class(
              "col-start-1 row-start-1 w-full whitespace-pre-wrap break-all invisible px-1 py-0.5 leading-relaxed min-h-[1.5em]",
            ),
          ],
          [element.text(checkpoint.title <> " ")],
        ),
        html.textarea(
          [
            attribute.value(checkpoint.title),
            attribute.rows(1),
            attribute.maxlength(100),
            attribute.class(
              "col-start-1 row-start-1 h-full w-full bg-transparent break-all text-stone-100 font-bold focus:outline-none focus:bg-stone-900/50 rounded-sm transition-colors resize-none overflow-hidden leading-relaxed px-1 py-0.5",
            ),
            event.on_input(CheckpointTitleUpdated(index, _)),
          ],
          checkpoint.title,
        ),
      ]),

      html.span([attribute.class("shrink-0 text-stone-400")], [
        element.text(time_to_string(parse_milliseconds(checkpoint.elapsed))),
      ]),
    ],
  )
}

type Time {
  Time(milliseconds: String, seconds: String, minutes: String, hours: String)
}

fn parse_milliseconds(milliseconds: Int) -> Time {
  let seconds = milliseconds / 1000
  let minutes = seconds / 60
  let hours = minutes / 60

  Time(
    milliseconds: int.to_string(milliseconds % 1000)
      |> string.pad_start(to: 3, with: "0"),
    seconds: int.to_string(seconds % 60) |> string.pad_start(to: 2, with: "0"),
    minutes: int.to_string(minutes % 60) |> string.pad_start(to: 2, with: "0"),
    hours: int.to_string(hours) |> string.pad_start(to: 2, with: "0"),
  )
}

fn time_to_string(time: Time) -> String {
  time.hours
  <> ":"
  <> time.minutes
  <> ":"
  <> time.seconds
  <> ":"
  <> time.milliseconds
}

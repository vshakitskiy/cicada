import app/component
import app/icon
import gleam/int
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

type Checkpoint {
  Checkpoint(elapsed: Int, title: String)
}

fn init(_nil) -> #(Model, effect.Effect(Message)) {
  #(Idle, effect.none())
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
      |> pair.new(tick())
    }
    Timer(..), TimerStarted -> panic as "unreachable"

    Timer(paused:, start_time:, current_time:, ..), TimerPauseToggled -> {
      let date = now()
      case paused {
        False ->
          Timer(..model, current_time: date, paused: True)
          |> pair.new(effect.none())

        True -> {
          let start_time = start_time + date - current_time
          Timer(..model, start_time:, current_time: date, paused: False)
          |> pair.new(tick())
        }
      }
    }
    Idle, TimerPauseToggled -> panic as "unreachable"

    Timer(..), TimerReset -> #(Idle, effect.none())
    Idle, TimerReset -> panic as "unreachable"

    Timer(start_time:, current_time:, checkpoints:, ..), CheckpointCaptured -> {
      let elapsed = current_time - start_time
      let next_id = list.length(checkpoints) + 1

      let title =
        "lap "
        <> { int.to_string(next_id) |> string.pad_start(to: 2, with: "0") }

      Timer(..model, checkpoints: [Checkpoint(elapsed:, title:), ..checkpoints])
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

      #(Timer(..model, checkpoints:), effect.none())
    }
    Idle, CheckpointTitleUpdated(..) -> panic as "unreachable"

    Timer(paused: False, ..), Ticked(date) ->
      Timer(..model, current_time: date) |> pair.new(tick())
    Timer(..), Ticked(..) | Idle, Ticked(..) -> #(model, effect.none())
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
        [attribute.class("w-full max-w-xs flex flex-col")],
        view_timer(model),
      ),
    ],
  )
}

fn view_timer(model: Model) {
  let #(elapsed, children) = case model {
    Idle -> #(
      0,
      component.button(on_click: TimerStarted, class: "mt-3", children: [
        icon.play("text-stone-950 size-7 mx-auto"),
      ]),
    )
    Timer(start_time:, current_time:, paused:, checkpoints:) -> {
      let elapsed = current_time - start_time
      let total_checkpoints = list.length(checkpoints)
      let checkpoints =
        list.index_map(checkpoints, fn(checkpoint, index) {
          #(
            "checkpoint@" <> int.to_string(index),
            view_checkpoint(total_checkpoints, index, checkpoint),
          )
        })

      #(
        elapsed,
        element.fragment([
          html.div([attribute.class("mt-3 flex gap-1")], [
            component.button(on_click: TimerPauseToggled, class: "", children: [
              case paused {
                True -> icon.play("text-stone-950 size-7 mx-auto")
                False -> icon.stop("text-stone-950 size-7 mx-auto")
              },
            ]),
            component.button(on_click: TimerReset, class: "py-1", children: [
              icon.reset("text-stone-950 size-5 mx-auto"),
            ]),
          ]),
          component.button(
            on_click: CheckpointCaptured,
            class: "py-1 mt-1",
            children: [
              icon.checkpoint("text-stone-950 size-5 mx-auto"),
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
        ]),
      )
    }
  }

  [
    html.p([attribute.class("text-3xl text-center select-none")], [
      element.text(time_to_string(parse_milliseconds(elapsed))),
    ]),
    children,
  ]
}

fn view_checkpoint(
  total: Int,
  index: Int,
  checkpoint: Checkpoint,
) -> element.Element(Message) {
  html.li(
    [
      attribute.class(
        "flex justify-between w-full items-center py-2 px-1 border-b last:border-none gap-2 border-stone-800 text-stone-400 font-mono text-xs",
      ),
    ],
    [
      html.span([attribute.class("text-stone-500 shrink-0")], [
        element.text("#"),
        element.text(
          int.to_string(total - index) |> string.pad_start(to: 2, with: "0"),
        ),
      ]),

      // smoll invisible mirror trick for textarea resize for all browser 
      // engines
      html.div([attribute.class("grid grow relative")], [
        html.div(
          [
            attribute.class(
              "col-start-1 row-start-1 w-full whitespace-pre-wrap break-all invisible text-stone-100 font-bold px-1 py-0.5 leading-relaxed min-h-[1.5em]",
            ),
          ],
          [element.text(checkpoint.title <> " ")],
        ),
        html.textarea(
          [
            attribute.value(checkpoint.title),
            attribute.rows(1),
            attribute.maxlength(50),
            attribute.class(
              "col-start-1 row-start-1 h-full w-full bg-transparent break-all text-stone-100 font-bold focus:outline-none focus:bg-stone-900/50 rounded-sm text-left transition-colors resize-none overflow-hidden leading-relaxed px-1 py-0.5",
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

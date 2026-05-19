import lustre
import lustre/effect
import lustre/element

pub fn main() -> Nil {
  let app = lustre.application(init:, update:, view:)
  let assert Ok(_runtime) = lustre.start(app, "#app", Nil)

  Nil
}

pub type Model {
  Model
}

fn init(_nil) -> #(Model, effect.Effect(Message)) {
  #(Model, effect.none())
}

pub type Message

fn update(model: Model, _message: Message) -> #(Model, effect.Effect(Message)) {
  #(model, effect.none())
}

fn view(_model: Model) -> element.Element(Message) {
  element.fragment([])
}

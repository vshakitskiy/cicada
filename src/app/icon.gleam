import lustre/attribute
import lustre/element
import lustre/element/svg

fn layout(
  class: String,
  children: List(element.Element(a)),
) -> element.Element(a) {
  svg.svg(
    [
      attribute.attribute("xmlns", "http://www.w3.org/2000/svg"),
      attribute.attribute("width", "16"),
      attribute.attribute("height", "16"),
      attribute.attribute("viewBox", "0 0 16 16"),
      attribute.attribute("fill", "currentColor"),
      attribute.class(class),
    ],
    children,
  )
}

pub fn play(class: String) -> element.Element(a) {
  layout(class, [
    svg.path([
      attribute.attribute(
        "d",
        "m11.596 8.697-6.363 3.692c-.54.313-1.233-.066-1.233-.697V4.308c0-.63.692-1.01 1.233-.696l6.363 3.692a.802.802 0 0 1 0 1.393",
      ),
    ]),
  ])
}

pub fn stop(class: String) -> element.Element(a) {
  layout(class, [
    svg.path([
      attribute.attribute(
        "d",
        "M5 3.5h6A1.5 1.5 0 0 1 12.5 5v6a1.5 1.5 0 0 1-1.5 1.5H5A1.5 1.5 0 0 1 3.5 11V5A1.5 1.5 0 0 1 5 3.5",
      ),
    ]),
  ])
}

pub fn reset(class: String) -> element.Element(a) {
  layout(class, [
    svg.path([
      attribute.attribute("fill-rule", "evenodd"),
      attribute.attribute(
        "d",
        "M8 3a5 5 0 1 0 4.546 2.914.5.5 0 0 1 .908-.417A6 6 0 1 1 8 2z",
      ),
    ]),
    svg.path([
      attribute.attribute(
        "d",
        "M8 4.466V.534a.25.25 0 0 1 .41-.192l2.36 1.966c.12.1.12.284 0 .384L8.41 4.658A.25.25 0 0 1 8 4.466",
      ),
    ]),
  ])
}

pub fn checkpoint(class: String) -> element.Element(a) {
  layout(class, [
    svg.path([
      attribute.attribute(
        "d",
        "M14.778.085A.5.5 0 0 1 15 .5V8a.5.5 0 0 1-.314.464L14.5 8l.186.464-.003.001-.006.003-.023.009a12 12 0 0 1-.397.15c-.264.095-.631.223-1.047.35-.816.252-1.879.523-2.71.523-.847 0-1.548-.28-2.158-.525l-.028-.01C7.68 8.71 7.14 8.5 6.5 8.5c-.7 0-1.638.23-2.437.477A20 20 0 0 0 3 9.342V15.5a.5.5 0 0 1-1 0V.5a.5.5 0 0 1 1 0v.282c.226-.079.496-.17.79-.26C4.606.272 5.67 0 6.5 0c.84 0 1.524.277 2.121.519l.043.018C9.286.788 9.828 1 10.5 1c.7 0 1.638-.23 2.437-.477a20 20 0 0 0 1.349-.476l.019-.007.004-.002h.001",
      ),
    ]),
  ])
}

import lustre/attribute
import lustre/element
import lustre/element/html
import lustre/event

pub fn button(
  on_click on_click: a,
  class class: String,
  children children: List(element.Element(a)),
) -> element.Element(a) {
  let class = case class {
    "" -> ""
    class -> " " <> class
  }

  html.button(
    [
      attribute.class(
        "bg-stone-50 cursor-pointer rounded-sm w-full font-bold transition-colors duration-150 ease-out hover:bg-stone-200 active:bg-stone-300"
        <> class,
      ),
      event.on_click(on_click),
    ],
    children,
  )
}

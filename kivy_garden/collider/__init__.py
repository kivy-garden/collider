from kivy_garden.collider._version import __version__

from kivy_garden.collider._collider import \
    Collide2DPoly, CollideEllipse, CollideBezier

__all__ = ('Collide2DPoly', 'CollideBezier', 'CollideEllipse')


if __name__ == '__main__':
    from kivy.app import App
    from kivy.uix.widget import Widget
    from kivy.graphics import Line, Color, Rectangle
    from kivy.uix.button import Button
    from kivy.uix.boxlayout import BoxLayout
    from kivy.graphics.texture import Texture
    import itertools

    class CollideTester(Widget):

        def __init__(self, **kwargs):
            super(CollideTester, self).__init__(**kwargs)
            self.state = 'drawing'
            self.collider = None

        def on_touch_down(self, touch):
            if super(CollideTester, self).on_touch_down(touch):
                return True
            if not self.collide_point(*touch.pos):
                return False
            touch.grab(self)
            if self.state == 'drawing':
                with self.canvas:
                    Color(1, 0, 1, group='12345')
                    touch.ud['line'] = Line(points=[touch.x, touch.y],
                                            close=True, group='12345')

        def on_touch_move(self, touch):
            if touch.grab_current is not self:
                return super(CollideTester, self).on_touch_move(touch)
            if self.state == 'drawing':
                touch.ud['line'].points += [touch.x, touch.y]

        def on_touch_up(self, touch):
            if touch.grab_current is not self:
                return super(CollideTester, self).on_touch_up(touch)
            touch.ungrab(self)
            if self.state == 'drawing':
                self.state = 'testing'
                x_off, y_off = self.pos
                self.collider = Collide2DPoly(
                    [val - y_off if i % 2 else val - x_off
                     for i, val in enumerate(touch.ud['line'].points)],
                    cache=True)
                collider = self.collider

                texture = Texture.create(size=self.size)
                inside_c = [255, 255, 0]
                outside_c = [255, 0, 255]
                width = int(self.width)
                height = int(self.height)

                buf = bytearray(width * height * 3)
                points = list(itertools.product(range(width), range(height)))
                for (x, y), inside in zip(
                        points, collider.collide_points(points)):
                    pos = (x + y * width) * 3
                    buf[pos:pos + 3] = inside_c if inside else outside_c
                texture.blit_buffer(bytes(buf), colorfmt='rgb',
                                    bufferfmt='ubyte')
                self.canvas.remove_group('12345')
                with self.canvas:
                    Rectangle(texture=texture, pos=self.pos, size=self.size,
                              group='12345')

    class TestApp(App):

        def build(self):
            box = BoxLayout(orientation='vertical')
            tester = CollideTester(size_hint_y=0.9)
            btn = Button(text='Clear', size_hint_y=0.1)
            box.add_widget(tester)
            box.add_widget(btn)

            def clear_state(*largs):
                tester.state = 'drawing'
                tester.collider = None
                tester.canvas.remove_group('12345')
            btn.bind(on_release=clear_state)
            return box

    TestApp().run()

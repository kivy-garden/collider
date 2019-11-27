import pytest


def test_collider():
    from kivy_garden.collider import Collide2DPoly
    poly = Collide2DPoly([0, 0, 100, 0, 100, 100, 0, 100])
    assert (50, 50) in poly

'''
Collider
========

The collider module contains classes which can be used to test membership
of a point in some space. See individual class documentation for details.

.. image:: _static/Screenshot.png
    :align: right

To use it you first have to cythonize the code. To do that, cd to the directory
containing collider.pyx and::

    python setup.py build_ext --inplace
'''

__all__ = ('Collide2DPoly', 'CollideBezier', 'CollideEllipse')


cimport cython
from libc.stdlib cimport malloc, free
cdef extern from "math.h":
    double round(double val)
    double floor(double val)
    double ceil(double val)
    double cos(double x)
    double sin(double x)
    double tan(double x)
    double atan2(double y, double x)
    double fabs(double x)

DEF PI = 3.14159265358979323846

cdef inline double ellipe_tan_dot(
        double rx, double ry, double px, double py, double theta):
    return  ((rx ** 2 - ry ** 2) * cos(theta) * sin(theta) -
             px * rx * sin(theta) + py * ry * cos(theta))

cdef inline double ellipe_tan_dot_derivative(
        double rx, double ry, double px, double py, double theta):
    return  ((rx ** 2 - ry ** 2) * (cos(theta) ** 2 - sin(theta) ** 2) -
             px * rx * cos(theta) - py * ry * sin(theta))


cdef class Collide2DPoly(object):
    ''' Collide2DPoly checks whether a point is within a polygon defined by a
    list of corner points.

    Based on http://alienryderflex.com/polygon/

    For example, a simple triangle::

        >>> collider = Collide2DPoly([10., 10., 20., 30., 30., 10.],
        ... cache=True)
        >>> (0.0, 0.0) in collider
        False
        >>> (20.0, 20.0) in collider
        True

    The constructor takes a list of x,y points in the form of [x1,y1,x2,y2...]
    as the points argument. These points define the corners of the
    polygon. The boundary is linearly interpolated between each set of points.
    The x, and y values must be floating points.
    The cache argument, if True, will calculate membership for all the points
    so when collide_point is called it'll just be a table lookup.
    '''

    cdef double *cpoints
    cdef double *cconstant
    cdef double *cmultiple
    cdef char *cspace
    # bounding box of the polygon (inclusive, width/height add 1)
    # this is an integer
    cdef int min_x
    cdef int max_x
    cdef int min_y
    cdef int max_y
    # size of the cached array
    cdef int width
    cdef int height
    cdef int count
    cdef int empty

    @cython.cdivision(True)
    def __cinit__(self, points, cache=False, **kwargs):
        cdef int length = len(points)
        if length % 2:
            raise IndexError('Odd number of points provided')
        if length < 6:
            self.cpoints = NULL
            self.empty = 1
            return

        cdef int count = length / 2
        self.empty = 0
        self.count = count
        self.cpoints = <double *>malloc(length * cython.sizeof(double))
        self.cconstant = <double *>malloc(count * cython.sizeof(double))
        self.cmultiple = <double *>malloc(count * cython.sizeof(double))
        cdef double *cpoints = self.cpoints
        cdef double *cconstant = self.cconstant
        cdef double *cmultiple = self.cmultiple
        self.cspace = NULL
        if cpoints is NULL or cconstant is NULL or cmultiple is NULL:
            raise MemoryError()

        self.min_x = int(floor(min(points[0::2])))
        self.max_x = int(ceil(max(points[0::2])))
        self.min_y = int(floor(min(points[1::2])))
        self.max_y = int(ceil(max(points[1::2])))
        cdef int i_x, i_y, j_x, j_y, i
        cdef int j = count - 1, odd, x, y
        for i in range(length):
            cpoints[i] = points[i]
        if cache:
            for i in range(count):
                cpoints[2 * i] -= self.min_x
                cpoints[2 * i + 1] -= self.min_y

        for i in range(count):
            i_x = i * 2
            i_y = i_x + 1
            j_x = j * 2
            j_y = j_x + 1
            if cpoints[j_y] == cpoints[i_y]:
                cconstant[i] = cpoints[i_x]
                cmultiple[i] = 0.
            else:
                cconstant[i] = (cpoints[i_x] - cpoints[i_y] * cpoints[j_x] /
                               (cpoints[j_y] - cpoints[i_y]) +
                               cpoints[i_y] * cpoints[i_x] /
                               (cpoints[j_y] - cpoints[i_y]))
                cmultiple[i] = ((cpoints[j_x] - cpoints[i_x]) /
                               (cpoints[j_y] - cpoints[i_y]))
            j = i
        if cache:
            self.width = self.max_x - self.min_x + 1
            self.height = self.max_y - self.min_y + 1

            self.cspace = <char *>malloc(self.height * self.width * cython.sizeof(char))
            if self.cspace is NULL:
                raise MemoryError()

            for y in range(self.height):
                for x in range(self.width):
                    j = count - 1
                    odd = 0
                    for i in range(count):
                        i_y = i * 2 + 1
                        j_y = j * 2 + 1
                        if (cpoints[i_y] < y <= cpoints[j_y] or
                            cpoints[j_y] < y <= cpoints[i_y]):
                            odd ^= y * cmultiple[i] + cconstant[i] < x
                        j = i
                    self.cspace[y * self.width + x] = odd

    def __dealloc__(self):
        free(self.cpoints)
        free(self.cconstant)
        free(self.cmultiple)
        free(self.cspace)

    @cython.cdivision(True)
    cpdef collide_point(self, double x, double y):
        cdef double *points = self.cpoints
        cdef int x_, y_
        if self.empty or points is NULL or not (
                self.min_x <= x <= self.max_x and self.min_y <= y <= self.max_y):
            return False

        if self.cspace is not NULL:
            x_ = int(round(x - self.min_x))
            y_ = int(round(y - self.min_y))
            if not (0 <= x_ < self.width and 0 <= y_ < self.height):
                return False
            return self.cspace[y_ * self.width + x_]

        cdef int j = self.count - 1, odd = 0, i, i_y, j_y, i_x, j_x
        for i in range(self.count):
            i_y = i * 2 + 1
            j_y = j * 2 + 1
            if points[i_y] < y <= points[j_y] or points[j_y] < y <= points[i_y]:
                odd ^= y * self.cmultiple[i] + self.cconstant[i] < x
            j = i
        return odd

    @cython.cdivision(True)
    cpdef collide_points(self, points):
        return [self.collide_point(*p) for p in points]

    def __contains__(self, point):
        return self.collide_point(*point)

    def get_inside_points(self):
        '''Returns a list of all the points that are within the polygon.
        '''
        cdef int x, y
        cdef list points = []

        if self.empty:
            return points

        if self.cspace is not NULL:
            for x in range(self.width):
                for y in range(self.height):
                    if self.cspace[y * self.width + x]:
                        points.append((
                            int(x + self.min_x),
                            int(y + self.min_y),
                        ))
            return points

        for x in range(int(floor(self.min_x)), int(ceil(self.max_x)) + 1):
            for y in range(int(floor(self.min_y)), int(ceil(self.max_y)) + 1):
                if self.collide_point(x, y):
                    points.append((x, y))
        return points

    def bounding_box(self):
        '''Returns the bounding box containing the polygon as 4 points
        (x1, y1, x2, y2), where x1, y1 is the lower left and x2, y2 is the
        upper right point of the rectangle.
        '''
        return self.min_x, self.min_y, self.max_x, self.max_y

    def get_area(self):
        cdef int x, y, i
        cdef double count = 0

        if self.empty:
            return 0.

        # https://www.mathopenref.com/coordpolygonarea.html
        for i in range(self.count - 1):
            count += self.cpoints[2 * i] * self.cpoints[2 * (i + 1) + 1]
            count -= self.cpoints[2 * i + 1] * self.cpoints[2 * (i + 1)]

        i = self.count - 1
        count += self.cpoints[2 * i] * self.cpoints[1]
        count -= self.cpoints[2 * i + 1] * self.cpoints[0]
        count /= 2.
        return abs(count)

    def get_centroid(self):
        cdef double x = 0
        cdef double y = 0

        if self.empty:
            return 0, 0

        for i in range(self.count):
            x += self.cpoints[2 * i]
            y += self.cpoints[2 * i + 1]

        x = x / float(self.count)
        y = y / float(self.count)

        if self.cspace is not NULL:
            return x + self.min_x, y + self.min_y
        return x , y


cdef list convert_to_poly(points, int segments):
        cdef double x, y, l
        cdef list T = list(points)
        cdef list poly = []

        for x in range(segments):
            l = x / (1.0 * segments)
            # http://en.wikipedia.org/wiki/De_Casteljau%27s_algorithm
            # as the list is in the form of (x1, y1, x2, y2...) iteration is
            # done on each item and the current item (xn or yn) in the list is
            # replaced with a calculation of "xn + x(n+1) - xn" x(n+1) is
            # placed at n+2. Each iteration makes the list one item shorter
            for i in range(1, len(T)):
                for j in range(len(T) - 2 * i):
                    T[j] = T[j] + (T[j+2] - T[j]) * l

            # we got the coordinates of the point in T[0] and T[1]
            poly.append(T[0])
            poly.append(T[1])

        # add one last point to join the curve to the end
        poly.append(T[-2])
        poly.append(T[-1])
        return poly


cdef class CollideBezier(object):
    '''Takes a list of control points describing a Bezier curve and tests
    whether a point falls in the Bezier curve described by them.
    '''

    cdef Collide2DPoly line_collider

    def __cinit__(self, points, cache=False, int segments=180, **kwargs):
        cdef int length = len(points)
        if length % 2:
            raise IndexError('Odd number of points provided')
        if length < 6:
            return
        if segments <= 1:
            raise ValueError('Invalid segments value, must be >= 2')

        self.line_collider = Collide2DPoly(
            convert_to_poly(points, segments), cache=cache)

    @staticmethod
    def convert_to_poly(points, int segments=180):
        return convert_to_poly(points, segments)

    cpdef collide_point(self, double x, double y):
        if self.line_collider is None:
            return False
        return self.line_collider.collide_point(x, y)

    @cython.cdivision(True)
    cpdef collide_points(self, points):
        if self.line_collider is None:
            return [False, ] * len(points)
        return [self.line_collider.collide_point(*p) for p in points]

    def __contains__(self, point):
        if self.line_collider is None:
            return False
        return self.line_collider.collide_point(*point)

    def get_inside_points(self):
        if self.line_collider is None:
            return []
        return self.line_collider.get_inside_points()

    def bounding_box(self):
        if self.line_collider is None:
            return [0, 0, 0, 0]
        return self.line_collider.bounding_box()

    def get_area(self):
        if self.line_collider is None:
            return 0
        return self.line_collider.get_area()

    def get_centroid(self):
        if self.line_collider is None:
            return 0, 0
        return self.line_collider.get_centroid()


cdef class CollideEllipse(object):
    ''' CollideEllipse checks whether a point is within an ellipse or circle
    aligned with the Cartesian plain, as defined by a center point and a major
    and minor radius. That is, the major and minor axes are along the x and y
    axes.

    :Parameters:
        `x`: float
            the x position of the center of the ellipse
        `y`: float
            the y position of the center of the ellipse
        `rx`: float
            the radius of the ellipse along the x direction
        `ry`: float
            the radius of the ellipse along the y direction

    For example::

        >>> collider = CollideEllipse(x=0, y=10, rx=10, ry=10)
        >>> (0, 10) in collider
        True
        >>> (0, 0) in collider
        True
        >>> (10, 10) in collider
        True
        >>> (11, 10) in collider
        False
        >>>
        >>> collider = CollideEllipse(x=0, y=10, rx=20, ry=10)
        >>> (20, 10) in collider
        True
        >>> (21, 10) in collider
        False
    '''

    cdef double x, y
    cdef double rx, ry
    cdef double angle
    cdef double _rx_squared
    cdef double _ry_squared
    cdef int _circle
    cdef int _zero_circle

    @cython.cdivision(True)
    def __cinit__(self, double x, double y, double rx, double ry, angle=0,
                  **kwargs):
        if rx < 0. or ry < 0.:
            raise ValueError('The radii must be zero or positive')

        self.x = x
        self.y = y
        self.rx = rx
        self.ry = ry
        self.angle = -angle / 180. * PI
        self._circle = rx == ry
        self._rx_squared = rx ** 2
        self._ry_squared = ry ** 2
        self._zero_circle = self._rx_squared == 0 or self._ry_squared == 0

    @cython.cdivision(True)
    cpdef collide_point(self, double x, double y):
        if self._zero_circle:
            return False

        x -= self.x
        y -= self.y
        if self._circle:
            return x ** 2 + y ** 2 <= self._rx_squared

        if self.angle:
            x, y = x * cos(self.angle) - y * sin(self.angle), x * sin(self.angle) + y * cos(self.angle)
        return (x ** 2 / self._rx_squared + y ** 2 / self._ry_squared <= 1.)

    @cython.cdivision(True)
    cpdef collide_points(self, points):
        return [self.collide_point(*p) for p in points]

    def __contains__(self, point):
        return self.collide_point(*point)

    def get_inside_points(self):
        cdef int x1, y1, x2, y2, x, y
        cdef list points = []
        x1, y1, x2, y2 = self.bounding_box()

        for x in range(x1, x2 + 1):
            for y in range(y1, y2 + 1):
                if self.collide_point(x, y):
                    points.append((x, y))
        return points

    cpdef bounding_box(self):
        cdef double phi, t, x, x1, x2, y, y1, y2
        if self._zero_circle:
            return (0, 0, 0, 0)

        if not self.angle or self._circle:
            return (int(floor(-self.rx + self.x)), int(floor(-self.ry + self.y)),
                    int(ceil(self.rx + self.x)), int(ceil(self.ry + self.y)))

        # from http://stackoverflow.com/a/88020/778140
        phi = -self.angle
        t = atan2(-self.ry * tan(phi), self.rx)
        x1 = self.x + self.rx * cos(t) * cos(phi) - self.ry * sin(t) * sin(phi)
        t += PI
        x2 = self.x + self.rx * cos(t) * cos(phi) - self.ry * sin(t) * sin(phi)

        t = atan2(self.ry * tan(PI / 2. - phi), self.rx)
        y1 = self.y + self.ry * sin(t) * cos(phi) + self.rx * cos(t) * sin(phi)
        t += PI
        y2 = self.y + self.ry * sin(t) * cos(phi) + self.rx * cos(t) * sin(phi)

        if x2 < x1:
            x = x1
            x1 = x2
            x2 = x

        if y2 < y1:
            y = y1
            y1 = y2
            y2 = y

        return (int(floor(x1)), int(floor(y1)), int(ceil(x2)), int(ceil(y2)))

    def estimate_distance(self, double x, double y, double error=1e-5):
        # from http://www.ma.ic.ac.uk/~rn/distance2ellipse.pdf
        cdef double px, py
        cdef double theta, angle
        if self._zero_circle:
            return 0

        x -= self.x
        y -= self.y
        if self._circle:
            return fabs((x ** 2 + y ** 2) ** .5 - self.rx)

        if self.angle:
            x, y = x * cos(self.angle) - y * sin(self.angle), x * sin(self.angle) + y * cos(self.angle)

        theta = atan2(self.rx * y, self.ry * x)
        while fabs(ellipe_tan_dot(self.rx, self.ry, x, y, theta)) > error:
            theta -= ellipe_tan_dot(
                self.rx, self.ry, x, y, theta
                ) / ellipe_tan_dot_derivative(self.rx, self.ry, x, y, theta)

        px, py = self.rx * cos(theta), self.ry * sin(theta)
        return ((x - px) ** 2 + (y - py) ** 2) ** .5

    def get_area(self):
        return PI * self.rx * self.ry

    def get_centroid(self):
        return self.x, self.y

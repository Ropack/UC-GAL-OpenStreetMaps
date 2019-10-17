# Class representing visual representation of a vertex.
class VisualVertex
  # ID of +self+ as well as +vertex+
  attr_reader :id
  # Corresponding vertex
  attr_reader :vertex
  # Lattitude of visual vertex
  attr_reader :lat
  # Longitute of visual vertex
  attr_reader :lon
  # X-axis position of +self+
  attr_reader :x
  # Y-axis position of +self+
  attr_reader :y

  # create instance of +self+ by simple storing of all parameters
  def initialize(id, vertex, lat, lon, x, y)
    @id = id
    @vertex = vertex
    @lat = lat
    @lon = lon
    @x = x
    @y = y
  end
end


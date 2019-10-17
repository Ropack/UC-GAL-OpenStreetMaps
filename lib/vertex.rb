# Class representing vertex in a graph
class Vertex
  # id of the +Vertex+
  attr_reader :id

  # create instance of +self+ by simple storing of all parameters
  def initialize id
    @id = id
  end
end


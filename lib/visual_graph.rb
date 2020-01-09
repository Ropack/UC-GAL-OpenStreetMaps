require 'ruby-graphviz'
require_relative 'visual_edge'
require_relative 'visual_vertex'

# Visual graph storing representation of graph for plotting.
class VisualGraph
  # Instances of +VisualVertex+ classes
  attr_reader :visual_vertices
  # Instances of +VisualEdge+ classes
  attr_reader :visual_edges
  # Corresponding +Graph+ Class
  attr_reader :graph
  # Scale for printing to output needed for GraphViz
  attr_reader :scale

  # Create instance of +self+ by simple storing of all given parameters.
  def initialize(graph, visual_vertices, visual_edges, bounds)
    @graph = graph
    @visual_vertices = visual_vertices
    @visual_edges = visual_edges
    @bounds = bounds
    @scale = ([bounds[:maxlon].to_f - bounds[:minlon].to_f, bounds[:maxlat].to_f - bounds[:minlat].to_f].min).abs / 10.0
  end

  # Export +self+ into Graphviz file given by +export_filename+.
  def export_graphviz(export_filename)
    # create GraphViz object from ruby-graphviz package
    graph_viz_output = GraphViz.new(:G,
                                    use: :neato,
                                    truecolor: true,
                                    inputscale: @scale,
                                    margin: 0,
                                    bb: "#{@bounds[:minlon]},#{@bounds[:minlat]},
                                  		    #{@bounds[:maxlon]},#{@bounds[:maxlat]}",
                                    outputorder: :nodesfirst)

    # append all vertices
    @visual_vertices.each { |k, v|
      n = graph_viz_output.add_nodes(v.id, :shape => 'point',
                                     :comment => "#{v.lat},#{v.lon}!",
                                     :pos => "#{v.y},#{v.x}!")
      if @highlighted_vertices.include? n.id
        n.set { |_n|
          _n.color = "red"
          _n.shape = 'point'
          _n.height = 0.2
          _n.fontsize = 0
        }
      end
    }

    # append all edges
    @visual_edges.each { |edge|
      graph_viz_output.add_edges(edge.v1.id, edge.v2.id, 'arrowhead' => 'none')
    }

    # export to a given format
    format_sym = export_filename.slice(export_filename.rindex('.') + 1, export_filename.size).to_sym
    graph_viz_output.output(format_sym => export_filename)
  end

  def export_console
    @visual_vertices.each { |k, v|
      puts "#{v.id} : #{v.lat}, #{v.lon}"
    }
  end

  def highlight_vertices(vertices)
    vertices.each do |v|
      unless @visual_vertices.any? { |k, val| val.id == v }
        puts "Vertex with id #{v} does not exist!"
        exit 1
      end
    end
    @highlighted_vertices = vertices
  end

  def get_nearest_vertex(lat, lon)
    first = @visual_vertices.values[0]
    nearest = {:id => first.id, :lat => first.lat.to_f, :lon => first.lon.to_f}
    @visual_vertices.each do |k, v|
      v_lat = v.lat.to_f
      v_lon = v.lon.to_f
      nearest = {:id => v.id, :lat => v_lat, :lon => v_lon} unless distance(nearest[:lat], nearest[:lon], lat, lon) < distance(v_lat, v_lon, lat, lon)
    end
    return nearest[:id]
  end

  def distance(lat1, lon1, lat2, lon2)
    Math.sqrt((lat1 - lat2) ** 2 + (lon1 - lon2) ** 2)
  end
end

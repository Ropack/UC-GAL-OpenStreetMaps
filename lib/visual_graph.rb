require 'ruby-graphviz'
require 'graphviz/theory'
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
    @highlighted_vertices = []
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
      e = graph_viz_output.add_edges(edge.v1.id, edge.v2.id, 'arrowhead' => 'none')
      if edge.emphasized
        e.set { |_e|
          _e.color = "red"
          _e.penwidth = 3
        }
      end
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
      @highlighted_vertices << v
    end
  end

  def highlight_path(path)
    (path.count - 1).times do |i|
      @visual_edges.find { |e| ([e.v1.id, e.v2.id] & [path[i], path[i+1]]).length == 2 }.emphasized = true
    end
  end

  def get_nearest_vertex(lat, lon)
    first = @visual_vertices.values[0]
    nearest = {:id => first.id, :lat => first.lat.to_f, :lon => first.lon.to_f}
    @visual_vertices.each do |k, v|
      v_lat = v.lat.to_f
      v_lon = v.lon.to_f
      nearest = {:id => v.id, :lat => v_lat, :lon => v_lon} unless distance_positions(nearest[:lat], nearest[:lon], lat, lon) < distance_positions(v_lat, v_lon, lat, lon)
    end
    return nearest[:id]
  end

  def distance_positions(lat1, lon1, lat2, lon2)
    # return Math.sqrt((lat1 - lat2) ** 2 + (lon1 - lon2) ** 2)
    r = 6371e3 # metres
    lat1rad = to_rad lat1
    lat2rad = to_rad lat2
    lon1rad = to_rad lon1
    lon2rad = to_rad lon2
    delta_lat = lat1rad - lat2rad
    delta_lon = lon1rad - lon2rad
    x = delta_lon * Math.cos((lat1rad+lat2rad)/2)
    y = delta_lat
    Math.sqrt(x ** 2 + y ** 2) * r
  end

  def to_rad(deg)
    deg * Math::PI / 180
  end

  def distance_vertices(v1_id, v2_id)
    v1 = @visual_vertices[v1_id]
    v2 = @visual_vertices[v2_id]
    distance_positions(v1.lat.to_f, v1.lon.to_f, v2.lat.to_f, v2.lon.to_f)
  end

  # actually time of travel in minutes
  def distance_with_speed(v1_id, v2_id, max_speed)
    return distance_vertices(v1_id, v2_id) / max_speed * 0.06
  end

  def shortest_path_vertices(v1_id, v2_id)
    dijkstra(v1_id, v2_id)
  end

  def shortest_path_positions(lat1, lon1, lat2, lon2)
    v1_id = get_nearest_vertex(lat1, lon1)
    v2_id = get_nearest_vertex(lat2, lon2)
    shortest_path_vertices(v1_id, v2_id)
  end

  def dijkstra(v1_id, v2_id)
    unvisited = []
    active = []
    distances = {}
    neighbors = create_neighbor_matrix
    predecessors = {}
    @visual_vertices.each do |k, v|
      unvisited << v.id
      distances[v.id] = Float::INFINITY
      predecessors[v.id] = nil
    end
    active << v1_id
    distances[v1_id] = 0

    until unvisited.empty?
      active.each do |a|
        deleted = unvisited.delete(a)
        if(deleted == v2_id)
          return [create_path(v1_id, v2_id, predecessors), distances[v2_id]]
        end

        neighbors[a].select { |n| unvisited.include? n[:id] }.each do |neighbor|
          n_id = neighbor[:id]
          max_speed = neighbor[:max_speed]
          new_distance = distances[a] + distance_with_speed(a, n_id, max_speed)
          if new_distance < distances[n_id]
            distances[n_id] = new_distance
            predecessors[n_id] = a
          end
        end

      end
      active = unvisited.group_by { |x| distances[x] }.min_by(&:first).last
    end

  end

  def create_path(v1_id, v2_id, predecessors)
    path = []
    a = v2_id
    unless(predecessors[a] == nil || v2_id == v1_id)
      until a == nil
        path.unshift a
        a = predecessors[a]
      end
    end
    return path
  end

  def create_neighbor_matrix
    neighbors = {}
    @visual_vertices.each do |k, v|
      neighbors[v.id] = []
    end
    @visual_edges.each do |e|
      neighbors[e.v1.id] << {:id => e.v2.id, :max_speed => e.edge.max_speed}
      neighbors[e.v2.id] << {:id => e.v1.id, :max_speed => e.edge.max_speed}
    end
    neighbors
  end
end

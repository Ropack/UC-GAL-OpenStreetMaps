require_relative '../process_logger'
require 'nokogiri'
require_relative 'graph'
require_relative 'visual_graph'

# Class to load graph from various formats. Actually implemented is Graphviz formats. Future is OSM format.
class GraphLoader
  attr_reader :highway_attributes

  # Create an instance, save +filename+ and preset highway attributes
  def initialize(filename, highway_attributes)
    @filename = filename
    @highway_attributes = highway_attributes
  end

  # Load graph from Graphviz file which was previously constructed from this application, i.e. contains necessary data.
  # File needs to contain
  # => 1) For node its 'id', 'pos' (containing its re-computed position on graphviz space) and 'comment' containig string with comma separated lat and lon
  # => 2) Edge (instead of source and target nodes) might contains info about 'speed' and 'one_way'
  # => 3) Generaly, graph contains parametr 'bb' containing array withhou bounds of map as minlon, minlat, maxlon, maxlat
  #
  # @return [+Graph+, +VisualGraph+]
  def load_graph_viz()
    ProcessLogger.log("Loading graph from GraphViz file #{@filename}.")
    gv = GraphViz.parse(@filename)

    # aux data structures
    hash_of_vertices = {}
    list_of_edges = []
    hash_of_visual_vertices = {}
    list_of_visual_edges = []

    # process vertices
    ProcessLogger.log("Processing vertices")
    gv.node_count.times { |node_index|
      node = gv.get_node_at_index(node_index)
      vid = node.id

      v = Vertex.new(vid) unless hash_of_vertices.has_key?(vid)
      ProcessLogger.log("\t Vertex #{vid} loaded")
      hash_of_vertices[vid] = v

      geo_pos = node["comment"].to_s.delete("\"").split(",")
      pos = node["pos"].to_s.delete("\"").split(",")
      hash_of_visual_vertices[vid] = VisualVertex.new(vid, v, geo_pos[0], geo_pos[1], pos[1], pos[0])
      ProcessLogger.log("\t Visual vertex #{vid} in ")
    }

    # process edges
    gv.edge_count.times { |edge_index|
      link = gv.get_edge_at_index(edge_index)
      vid_from = link.node_one.delete("\"")
      vid_to = link.node_two.delete("\"")
      speed = 50
      one_way = false
      link.each_attribute { |k, v|
        speed = v if k == "speed"
        one_way = true if k == "oneway"
      }
      e = Edge.new(vid_from, vid_to, speed, one_way)
      list_of_edges << e
      list_of_visual_edges << VisualEdge.new(e, hash_of_visual_vertices[vid_from], hash_of_visual_vertices[vid_to])
    }

    # Create Graph instance
    g = Graph.new(hash_of_vertices, list_of_edges)

    # Create VisualGraph instance
    bounds = {}
    bounds[:minlon], bounds[:minlat], bounds[:maxlon], bounds[:maxlat] = gv["bb"].to_s.delete("\"").split(",")
    vg = VisualGraph.new(g, hash_of_visual_vertices, list_of_visual_edges, bounds)

    return g, vg
  end

  # Method to load graph from OSM file and create +Graph+ and +VisualGraph+ instances from +self.filename+
  #
  # @return [+Graph+, +VisualGraph+]
  def load_graph()

    # aux data structures
    hash_of_vertices = {}
    list_of_edges = []
    hash_of_visual_vertices = {}
    list_of_visual_edges = []
    @neighbor_vertices = {}


    File.open(@filename, "r") do |file|
      doc = Nokogiri::XML::Document.parse(file)
      doc.root.xpath("way").each do |way|
        highway_tag = way.at_xpath("tag[@k='highway']")
        unless highway_tag.nil?
          if @highway_attributes.include?(highway_tag["v"])
            nds = way.xpath("nd")
            nds.each_with_index do |nd, i|
              node_id = nd["ref"]
              node = doc.root.at_xpath("node[@id='#{node_id}']")

              ProcessLogger.log("\t Vertex #{node_id} loaded")

              unless hash_of_vertices.has_key?(node_id)
                hash_of_vertices[node_id] = Vertex.new(node_id)

                # TODO: Get position from lat and lon
                # hash_of_visual_vertices[node_id] = VisualVertex.new(node_id, v, node["lat"], node["lon"], pos[1], pos[0])

              end
              unless i == nds.length - 1
                node2_id = nds[i + 1]["ref"]
                list_of_edges << Edge.new(node_id, node2_id, 50, false)
                @neighbor_vertices[node_id] = [] unless @neighbor_vertices.has_key? node_id
                @neighbor_vertices[node2_id] = [] unless @neighbor_vertices.has_key? node2_id
                @neighbor_vertices[node_id] << node2_id
                @neighbor_vertices[node2_id] << node_id
              end
            end
          end
        end
      end
    end
    components = []
		visited_hash = {}
		index = 0
    @neighbor_vertices.each do |vertex, neighbors|
      unless visited_hash[vertex]
				components[index] = dfs_util(vertex, visited_hash)
				index += 1
			end
    end
    largest_component = components.max_by { |x| x.length }
		
  end

  def dfs_util(v, visited_hash)
    visited_hash[v] = true
    component = []
		component << v
    # Recur for all the vertices
    # adjacent to this vertex
    @neighbor_vertices[v].each do |neighbor|
      component.concat(dfs_util(neighbor, visited_hash)) unless visited_hash[neighbor];
    end
    return component
  end
end

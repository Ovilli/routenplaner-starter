# Ein Routenplaner: deine Funktionen. server.rb ruft sie auf und zeigt im
# Browser, was sie schon können.

def read_ways(path)
  result = []
  File.read(path, chomp: true).split("\n").each do |line|
    parts = line.split("\t", 4)
    kind = parts[0]
    oneway = parts[1]
    name = parts[2]
    points_str = parts[3]
    points_arr = []
    if points_str != nil && points_str != ''
      tokens = points_str.split
      i = 0
      while i < tokens.length
        id_part = tokens[i]
        latlon = tokens[i + 1]
        if latlon != nil
          ll = latlon.split(',')
          if ll.length == 2
            points_arr << [id_part, ll[0].to_f, ll[1].to_f]
          end
        end
        i += 2
      end
    end
    result << { :kind => kind, :oneway => oneway, :name => name, :points => points_arr }
  end
  return result
end

def distance(lon1, lat1, lon2, lat2)
  r = 6371000.0
  phi1 = lat1 * Math::PI / 180.0
  phi2 = lat2 * Math::PI / 180.0
  dphi = (lat2 - lat1) * Math::PI / 180.0
  dlambda = (lon2 - lon1) * Math::PI / 180.0
  a = Math.sin(dphi / 2.0) ** 2 + Math.cos(phi1) * Math.cos(phi2) * Math.sin(dlambda / 2.0) ** 2
  c = 2.0 * Math.atan2(Math.sqrt(a), Math.sqrt(1.0 - a))
  return r * c
end

def build_graph(ways)
  graph = { :nodes => {}, :edges => {} }
  ways.each do |way|
    points = way[:points]
    i = 0
    while i < points.length
      p = points[i]
      graph[:nodes][p[0]] = [p[1], p[2]]
      if graph[:edges][p[0]] == nil
        graph[:edges][p[0]] = []
      end
      i += 1
    end
    i = 0
    while i < points.length - 1
      p1 = points[i]
      p2 = points[i + 1]
      meters = distance(p1[1], p1[2], p2[1], p2[2])
      graph[:edges][p1[0]] << [p2[0], meters]
      graph[:edges][p2[0]] << [p1[0], meters]
      i += 1
    end
  end
  return graph
end

def path_to(previous, goal)
  if previous.key?(goal) == false
    return nil
  end
  result = []
  current = goal
  seen = {}
  while current != nil
    if seen.key?(current)
      return nil
    end
    seen[current] = true
    result << current
    current = previous[current]
  end
  result.reverse!
  return result
end

def breadth_first(graph, start, goal)
  edges = graph[:edges]
  visited = []
  previous = {}
  previous[start] = nil
  queue = []
  queue << start
  head = 0
  while head < queue.length
    current = queue[head]
    head = head + 1
    visited << current
    if current == goal
      return { :path => path_to(previous, goal), :visited => visited }
    end
    neighbors = edges[current]
    if neighbors == nil
      neighbors = []
    end
    i = 0
    while i < neighbors.length
      nb = neighbors[i]
      neighbor = nb[0]
      if !previous.key?(neighbor)
        previous[neighbor] = current
        queue << neighbor
      end
      i = i + 1
    end
  end
  return { :path => nil, :visited => visited }
end

def dijkstra(graph, start, goal)
  edges = graph[:edges]
  visited = []
  previous = {}
  previous[start] = nil
  dist = {}
  dist[start] = 0.0
  heap = MinHeap.new
  heap.push(0.0, start)
  while !heap.empty?
    prio_val = heap.pop
    if prio_val == nil
      break
    end
    prio = prio_val[0]
    current = prio_val[1]
    if dist[current] != nil && prio > dist[current] + 1e-12
      next
    end
    visited << current
    if current == goal
      return { :path => path_to(previous, goal), :visited => visited }
    end
    neighbors = edges[current]
    if neighbors == nil
      neighbors = []
    end
    i = 0
    while i < neighbors.length
      nb = neighbors[i]
      neighbor = nb[0]
      metres = nb[1]
      nd = prio + metres
      if dist[neighbor] == nil || nd < dist[neighbor] - 1e-12
        dist[neighbor] = nd
        previous[neighbor] = current
        heap.push(nd, neighbor)
      end
      i += 1
    end
  end
  return { :path => nil, :visited => visited }
end

class MinHeap
  def initialize
    @items = []
  end

  def empty?
    return @items.length == 0
  end

  def size
    return @items.length
  end

  def push(priority, value)
    @items << [priority, value]
    i = @items.length - 1
    while i > 0
      pidx = (i - 1) / 2
      if @items[pidx][0] <= @items[i][0]
        break
      end
      tmp = @items[pidx]
      @items[pidx] = @items[i]
      @items[i] = tmp
      i = pidx
    end
  end

  def pop
    if @items.length == 0
      return nil
    end
    root = @items[0]
    last = @items.pop
    if @items.length > 0
      @items[0] = last
      i = 0
      n = @items.length
      while true
        smallest = i
        left = 2 * i + 1
        right = 2 * i + 2
        if left < n && @items[left][0] < @items[smallest][0]
          smallest = left
        end
        if right < n && @items[right][0] < @items[smallest][0]
          smallest = right
        end
        if smallest == i
          break
        end
        tmp = @items[i]
        @items[i] = @items[smallest]
        @items[smallest] = tmp
        i = smallest
      end
    end
    return root
  end
end

def a_star(graph, start, goal)
  edges = graph[:edges]
  nodes = graph[:nodes]
  visited = []
  previous = {}
  previous[start] = nil
  dist = {}
  dist[start] = 0.0
  goal_pos = nodes[goal]
  heap = MinHeap.new
  start_pos = nodes[start]
  h_start = 0.0
  if goal_pos != nil && start_pos != nil
    h_start = distance(start_pos[0], start_pos[1], goal_pos[0], goal_pos[1])
  end
  heap.push(h_start, start)
  while !heap.empty?
    prio_f = heap.pop
    if prio_f == nil
      break
    end
    fcur = prio_f[0]
    current = prio_f[1]
    g_cur = dist[current]
    if g_cur == nil
      next
    end
    cpos = nodes[current]
    h_cur = 0.0
    if goal_pos != nil && cpos != nil
      h_cur = distance(cpos[0], cpos[1], goal_pos[0], goal_pos[1])
    end
    if fcur > g_cur + h_cur + 1e-12
      next
    end
    visited << current
    if current == goal
      return { :path => path_to(previous, goal), :visited => visited }
    end
    neighbors = edges[current]
    if neighbors == nil
      neighbors = []
    end
    i = 0
    while i < neighbors.length
      nb = neighbors[i]
      neighbor = nb[0]
      metres = nb[1]
      ng = g_cur + metres
      if dist[neighbor] == nil || ng < dist[neighbor] - 1e-12
        dist[neighbor] = ng
        previous[neighbor] = current
        npos = nodes[neighbor]
        hn = 0.0
        if goal_pos != nil && npos != nil
          hn = distance(npos[0], npos[1], goal_pos[0], goal_pos[1])
        end
        heap.push(ng + hn, neighbor)
      end
      i += 1
    end
  end
  return { :path => nil, :visited => visited }
end

SPEEDS = {
  'foot' => { 'footway' => 5, 'path' => 5, 'pedestrian' => 5, 'steps' => 2, 'living_street' => 5,
              'residential' => 5, 'service' => 5, 'unclassified' => 5, 'tertiary' => 5, 'secondary' => 5,
              'primary' => 5, 'track' => 5, 'cycleway' => 5, 'bridleway' => 5, 'ferry' => 5 },
  'bike' => { 'cycleway' => 18, 'residential' => 15, 'living_street' => 10, 'service' => 12,
              'unclassified' => 15, 'tertiary' => 16, 'secondary' => 16, 'primary' => 16,
              'tertiary_link' => 15, 'secondary_link' => 15, 'primary_link' => 15,
              'path' => 12, 'track' => 10, 'bridleway' => 10, 'ferry' => 10 },
  'car' => { 'motorway' => 90, 'motorway_link' => 50, 'trunk' => 60, 'trunk_link' => 40,
             'primary' => 50, 'primary_link' => 30, 'secondary' => 45, 'secondary_link' => 30,
             'tertiary' => 40, 'tertiary_link' => 30, 'unclassified' => 30, 'residential' => 25,
             'living_street' => 7, 'service' => 10, 'ferry' => 10 }
}

def build_travel_graph(ways, mode)
  speeds = SPEEDS[mode]
  if speeds == nil
    raise NotImplementedError, 'build_travel_graph'
  end
  graph = { :nodes => {}, :edges => {}, :fastest => 0.0 }
  ways.each do |way|
    kind = way[:kind]
    if speeds.key?(kind) == false
      next
    end
    speed_kmh = speeds[kind]
    speed_ms = speed_kmh / 3.6
    if speed_ms > graph[:fastest]
      graph[:fastest] = speed_ms
    end
    oneway = way[:oneway]
    points = way[:points]
    i = 0
    while i < points.length
      p = points[i]
      graph[:nodes][p[0]] = [p[1], p[2]]
      if graph[:edges][p[0]] == nil
        graph[:edges][p[0]] = []
      end
      i += 1
    end
    i = 0
    while i < points.length - 1
      p1 = points[i]
      p2 = points[i + 1]
      meters = distance(p1[1], p1[2], p2[1], p2[2])
      seconds = meters / speed_ms
      if mode == 'car' && oneway == 'yes'
        graph[:edges][p1[0]] << [p2[0], seconds]
      else
        graph[:edges][p1[0]] << [p2[0], seconds]
        graph[:edges][p2[0]] << [p1[0], seconds]
      end
      i += 1
    end
  end
  return graph
end

def tour_length(costs, order)
  total = 0.0
  n = order.length
  i = 0
  while i < n
    a = order[i]
    b = order[(i + 1) % n]
    total += costs[a][b]
    i += 1
  end
  return total
end

def best_tour(costs)
  n = costs.length
  if n <= 1
    res = []
    i = 0
    while i < n
      res << i
      i += 1
    end
    return res
  end
  best_order = nil
  best_len = 1e18
  arr = []
  i = 0
  while i < n
    arr << i
    i += 1
  end
  arr.permutation do |perm|
    l = tour_length(costs, perm)
    if l < best_len
      best_len = l
      best_order = perm.dup
    end
  end
  if best_order == nil
    return arr
  end
  return best_order
end

def nearest_tour(costs)
  n = costs.length
  if n == 0
    return []
  end
  visited = Array.new(n, false)
  order = []
  order << 0
  visited[0] = true
  current = 0
  while order.length < n
    best_j = -1
    best_c = 1e18
    j = 0
    while j < n
      if visited[j] == false
        c = costs[current][j]
        if c < best_c
          best_c = c
          best_j = j
        end
      end
      j += 1
    end
    if best_j == -1
      break
    end
    order << best_j
    visited[best_j] = true
    current = best_j
  end
  return order
end

def improve_tour(costs, order)
  order_arr = order.dup
  n = order_arr.length
  improved = true
  while improved
    improved = false
    i = 0
    while i < n
      j = i + 2
      while j < n + i - 1
        j_mod = j % n
        if j_mod != i
          new_order = order_arr.dup
          seg = new_order[(i + 1)...j_mod]
          new_order[(i + 1)...j_mod] = seg.reverse
          if tour_length(costs, new_order) < tour_length(costs, order_arr) - 1e-12
            order_arr = new_order
            improved = true
            break
          end
        end
        j += 1
      end
      if improved
        break
      end
      i += 1
    end
  end
  return order_arr
end

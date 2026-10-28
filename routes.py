# Ein Routenplaner: deine Funktionen. server.py ruft sie auf und zeigt im
# Browser, was sie schon können.
import itertools
import math


# Liest die Wege einer Datei aus data/. Jede Zeile ist ein Weg, die Teile sind
# durch Tabulatoren getrennt: Art, Einbahnstraße, Name, Punkte. Die Punkte
# sind »ID LÄNGE,BREITE ID LÄNGE,BREITE …«.
#
# Gibt eine Liste von Dictionaries zurück, eines pro Weg:
#   {'kind': 'residential', 'oneway': '', 'name': 'Schloßstraße',
#    'points': [['26735834', 13.3266, 52.4567], …]}
def read_ways(path):
    ways = []
    with open(path, encoding='utf-8') as f:
        for line in f:
            kind, oneway, name, points = line.rstrip('\n').split('\t')
            tokens = points.split()
            ways.append({
                'kind': kind,
                'oneway': oneway,
                'name': name,
                'points': [[tokens[i], *map(float, tokens[i + 1].split(','))] for i in range(0, len(tokens), 2)],
            })
    return ways
    


# Der Abstand zweier Punkte in Metern
def distance(lon1, lat1, lon2, lat2):
    return 6371000 * math.acos(math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) *
                               math.cos(math.radians(lon2) - math.radians(lon1)) +
                               math.sin(math.radians(lat1)) * math.sin(math.radians(lat2)))


# Der Graph aus den Wegen:
#   'nodes': {ID: [Länge, Breite]} für jeden Punkt
#   'edges': {ID: [[Nachbar-ID, Meter], …]} für jeden Punkt, in beide Richtungen
def build_graph(ways):
    graph = {'nodes': {}, 'edges': {}}
    for way in ways:
        points = way['points']
        for node_id, lon, lat in points:
            graph['nodes'][node_id] = [lon, lat]
            graph['edges'].setdefault(node_id, [])
        for (id1, lon1, lat1), (id2, lon2, lat2) in itertools.pairwise(points):
            meters = distance(lon1, lat1, lon2, lat2)
            graph['edges'][id1].append([id2, meters])
            graph['edges'][id2].append([id1, meters])
    return graph


# Der Weg zum Ziel, rückwärts aus den Vorgängern: previous sagt für jeden
# gefundenen Knoten, von welchem aus er gefunden wurde (der Start von None).
# Gibt die IDs vom Start bis zum Ziel zurück, None, wenn das Ziel nicht dabei ist.
def path_to(previous, goal):
    result = []
    while goal is not None:
        result.append(goal)
        goal = previous[goal]
    result.reverse()
    return result


# Breitensuche: der Weg über die wenigsten Kanten. Gibt zurück:
#   {'path': [Start-ID, …, Ziel-ID] (oder None, wenn es keinen Weg gibt),
#    'visited': [ID, …]}  die besuchten Knoten, in der Reihenfolge der Suche
def breadth_first(graph, start, goal):
    graph = graph['edges']
    visited = []
    previous = {start: None}
    queue = [start]
    while queue:
        current = queue.pop(0)
        visited.append(current)
        if current == goal:
            return {'path': path_to(previous, goal), 'visited': visited}
        for neighbor, _ in graph.get(current, []):
            if neighbor not in previous:
                previous[neighbor] = current
                queue.append(neighbor)
    return {'path': None, 'visited': visited}    


# Dijkstra: der kürzeste Weg in Metern. Gibt dasselbe zurück wie breadth_first.
def dijkstra(graph, start, goal):
    raise NotImplementedError('dijkstra')


# Eine Priority Queue: push legt einen Wert mit einer Priorität
# hinein, pop gibt das Paar (Priorität, Wert) mit der kleinsten Priorität
# zurück und nimmt es heraus (None, wenn sie leer ist).
class MinHeap:
    def __init__(self):
        self.items = []  # (Priorität, Wert), als binärer Heap

    def empty(self):
        return not self.items

    def __len__(self):
        return len(self.items)

    def push(self, priority, value):
        raise NotImplementedError('MinHeap.push')

    def pop(self):
        raise NotImplementedError('MinHeap.pop')


# A*: wie Dijkstra, mit der Luftlinie zum Ziel als Schätzung für den Rest.
# Gibt dasselbe zurück wie breadth_first.
def a_star(graph, start, goal):
    raise NotImplementedError('a_star')


# Wie schnell man auf welcher Art von Weg vorankommt, in km/h. Was in der
# Liste einer Art zu reisen fehlt, darf man so nicht benutzen.
SPEEDS = {
    'foot': {'footway': 5, 'path': 5, 'pedestrian': 5, 'steps': 2, 'living_street': 5,
             'residential': 5, 'service': 5, 'unclassified': 5, 'tertiary': 5, 'secondary': 5,
             'primary': 5, 'track': 5, 'cycleway': 5, 'bridleway': 5, 'ferry': 5},
    'bike': {'cycleway': 18, 'residential': 15, 'living_street': 10, 'service': 12,
             'unclassified': 15, 'tertiary': 16, 'secondary': 16, 'primary': 16,
             'tertiary_link': 15, 'secondary_link': 15, 'primary_link': 15,
             'path': 12, 'track': 10, 'bridleway': 10, 'ferry': 10},
    'car': {'motorway': 90, 'motorway_link': 50, 'trunk': 60, 'trunk_link': 40,
            'primary': 50, 'primary_link': 30, 'secondary': 45, 'secondary_link': 30,
            'tertiary': 40, 'tertiary_link': 30, 'unclassified': 30, 'residential': 25,
            'living_street': 7, 'service': 10, 'ferry': 10},
}


# Der Graph für eine Art zu reisen ('foot', 'bike', 'car'): wie build_graph,
# aber nur mit den Wegen, die man so benutzen darf, und mit Sekunden statt
# Metern an den Kanten. Für das Auto gelten die Einbahnstraßen.
#   {'nodes': …, 'edges': …, 'fastest': das größte Tempo in Metern je Sekunde}
def build_travel_graph(ways, mode):
    raise NotImplementedError('build_travel_graph')


# Eine Rundfahrt durch mehrere Orte: costs[i][j] sagt, wie weit es von Ort i
# zu Ort j ist. Eine Reihenfolge ist eine Liste von Nummern der Orte; sie
# beginnt bei 0 und kehrt am Ende zu ihrem Anfang zurück.

# Wie lang eine Rundfahrt in dieser Reihenfolge ist, mit dem Weg zurück
def tour_length(costs, order):
    raise NotImplementedError('tour_length')


# Die beste Reihenfolge, durch Ausprobieren aller
def best_tour(costs):
    raise NotImplementedError('best_tour')


# Immer zum nächsten Ort, an dem die Rundfahrt noch nicht war
def nearest_tour(costs):
    raise NotImplementedError('nearest_tour')


# Eine Reihenfolge mit 2-opt verbessern: ein Stück umdrehen, solange die
# Rundfahrt dadurch kürzer wird
def improve_tour(costs, order):
    raise NotImplementedError('improve_tour')

#!/usr/bin/env python3
import sys, heapq

def smallest_at_index(my_list):
    smallest = 0;
    for i in range(len(my_list)):
        if my_list[i] < my_list[smallest]:
            smallest = i
    return smallest
#############################################
source = sys.argv[1];
dest = sys.argv[2];
town_map = {}
for line in sys.stdin.readlines():
    line = line.strip()
    town1, town2, dist = line.split()
    dist = int(dist)
    if (town1 not in town_map):
        town_map[town1] = {}
    if (town2 not in town_map):     # keep this even if directed graph
        town_map[town2] = {}
    town_map[town1][town2] = dist
    town_map[town2][town1] = dist   # assuming undirected
# Dijkstra
visited = []
pred = {}
for town in town_map.keys():    # list as: pred_town, total_dist
    pred[town] = ['', -1]
# data validate
if (source not in town_map.keys() or dest not in town_map.keys()):
    print("No route available")
    sys.exit(1)

pq_town = [source]
pq_dist = [0]
found = False
while (len(pq_town) and not found):
    # pop off 'priority queue'
    cur_index = smallest_at_index(pq_dist)
    cur_town = pq_town.pop(cur_index)
    cur_dist = pq_dist.pop(cur_index)
    # break if at dest
    if cur_town == dest:
        found = True
        break
    # continue if already visited
    if (cur_town in visited):
        continue;
    visited.append(cur_town)
    # get neighbours
    for new_town in sorted(town_map[cur_town].keys()):
        new_dist = cur_dist + town_map[cur_town][new_town]
        # edge relaxation
        if pred[new_town][1] == -1 or new_dist < pred[new_town][1]:
            pred[new_town] = [cur_town, new_dist]
        # add to pq
        pq_town.append(new_town)
        pq_dist.append(new_dist)
# backtrack
path_length = pred[dest][1]
if path_length == -1:
    print("No route available to", dest)
    sys.exit(1)
reverse_path = []   # there must be a path
cur_town = dest
while True:
    reverse_path.append(cur_town)
    if cur_town == source:
        break
    cur_town = pred[cur_town][0]
# output
print("Shortest route is length = {}:".format(path_length), end='')
for cur_town in reversed(reverse_path):
    print(" {}".format(cur_town), end='')
print('.')

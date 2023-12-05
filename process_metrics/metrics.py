import csv
import requests
from datetime import datetime

url = "http://44.219.140.102:9090"
time_step = {
    'start': "2023-12-03T02:20:00Z",
    'end': "2023-12-03T03:49:00Z", # + 5hr
    'step': '1m'
}
matrics_params = {
    'cpu': {
        'query': """(sum by(instance)(irate(node_cpu_seconds_total{job="backend_node_exporter", mode!="idle"}[1m])) / on(instance) group_left sum by (instance)((irate(node_cpu_seconds_total{job="backend_node_exporter"}[1m])))) * 100""",
        **time_step
    },
    'mem': {
        'query': """rate(jvm_memory_bytes_used{job="jmx_exporter"}[1m])""",
        **time_step
    },
    'net_i': {
        'query': """irate(node_network_receive_bytes_total{job="backend_node_exporter", device="enX0"}[1m])*8""",
        **time_step
    },
    'net_o': {
        'query': """irate(node_network_transmit_bytes_total{job="backend_node_exporter", device="enX0"}[1m])*8""",
        **time_step
    },
    'disk_io': {
        'query': """irate(node_disk_io_time_seconds_total{job="db_node_exporter", device="xvda"}[1m])*100""",
        **time_step
    },
    'disk_read': {
        'query': """irate(node_disk_read_bytes_total{job="db_node_exporter", device="xvda"}[1m])""",
        **time_step
    },
    'disk_write': {
        'query': """irate(node_disk_written_bytes_total{job="db_node_exporter", device="xvda"}[1m])""",
        **time_step
    }
}

def send_request(params):
    response = requests.get(f"{url}/api/v1/query_range", params=params)
    return response.json()['data']['result']

def unix_to_timestamp(unix):
    return datetime.utcfromtimestamp(unix).strftime('%Y-%m-%d %H:%M:%S')

def main():
    values = {}
    for name, param in matrics_params.items():
        result = send_request(param)
        if name == 'mem':
            values['mem_heap'] = result[0]['values']
            values['mem_nonheap'] = result[1]['values']
        else:
            values[name] = result[0]['values']
    
    length = len(values['cpu'])

    with open('matrics.csv', 'w', newline='') as csvfile:
        writer = csv.writer(csvfile)
        # Timestamp	CPU(%)	Memory_heap(b/s)	Memory_nonheap	Network_I(b/s)	Network_O(b/s)	Net(Packet)	Disk_I(%)	Disk_O(%)	Res(mean)	Res(medium)
        writer.writerow(['Timestamp', 'CPU(%)', 'Mem Heap(b/s)', 'Mem Nonheap(b/s)',
                          'Net I(b/s)', 'Net O(b/s)', 'Disk io(%)', 'Disk read(kB/s)', 'Disk write(kB/s)'])

        for i in range(0, length-1):
            timestamp = unix_to_timestamp(values['cpu'][i][0])
            row = [timestamp]
            for key, value in values.items():
                row.append(value[i][1])
            writer.writerow(row)
    
main()

"""
http://44.219.140.102:9090/api/v1/query_range?query=irate(process_cpu_seconds_total{job="jmx_exporter"}[1m])*100&start=2023-12-01T12:30:00Z&end=2023-12-03T12:50:00Z&step=1m
http://44.219.140.102:9090/api/v1/query_range?query=irate(jvm_memory_bytes_used{job="jmx_exporter"}[1m])&start=2023-12-03T02:20:00Z&end=2023-12-03T03:49:00Z&step=1m
http://44.219.140.102:9090/api/v1/query_range?query=irate(node_network_receive_bytes_total{job="backend_node_exporter", device="eth0"}[1m])*8&start=2023-12-02T18:00:00Z&end=2023-12-02T23:15:00Z&step=1m
http://44.219.140.102:9090/api/v1/query_range?query=irate(node_disk_io_time_seconds_total{job="db_node_exporter", device="xvda"}[1m])&start=2023-12-02T18:00:00Z&end=2023-12-02T23:15:00Z&step=1m
http://44.219.140.102:9090/api/v1/query_range?query=(sum by(instance)(irate(node_cpu_seconds_total{job="backend_node_exporter", mode!="idle"}[1m])) / on(instance) group_left sum by (instance)((irate(node_cpu_seconds_total{job="backend_node_exporter"}[1m])))) * 100&start=2023-12-02T18:00:00Z&end=2023-12-02T23:15:00Z&step=1m
"""

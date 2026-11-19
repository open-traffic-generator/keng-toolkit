#!/usr/bin/env python3

import argparse
import logging
import time

import urllib3
from urllib3.exceptions import InsecureRequestWarning

import snappi

urllib3.disable_warnings(InsecureRequestWarning)

logger = logging.getLogger("quickstart_cp_dp")
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

POLL_INTERVAL_SECONDS = 1


def build_config(port_a: str, port_z: str, location: str = "https://localhost:8443"):
    api = snappi.api(location=location)
    cfg = api.config()

    p1 = cfg.ports.add(name="p1", location=port_a)
    p2 = cfg.ports.add(name="p2", location=port_z)

    d1 = cfg.devices.add(name="d1")
    d2 = cfg.devices.add(name="d2")

    d1_eth = d1.ethernets.add(name="d1Eth", mac="00:00:01:01:01:01", mtu=1500)
    d1_eth.connection.port_name = p1.name
    d1_ipv4 = d1_eth.ipv4_addresses.add(
        name="p1d1ipv4",
        address="1.1.1.1",
        gateway="1.1.1.2",
        prefix=24,
    )

    d1_bgp = d1.bgp
    d1_bgp.router_id = "1.1.1.1"
    d1_bgp_if = d1_bgp.ipv4_interfaces.add(ipv4_name=d1_ipv4.name)
    d1_peer = d1_bgp_if.peers.add(
        name="BGP Peer 1",
        peer_address="1.1.1.2",
        as_number=1111,
        as_type="ebgp",
    )
    d1_route = d1_peer.v4_routes.add(
        name="p1d1peer1rrv4",
        next_hop_ipv4_address="1.1.1.1",
        next_hop_address_type="ipv4",
        next_hop_mode="manual",
    )
    d1_route.addresses.add(address="10.10.10.0", prefix=24, count=2, step=2)
    d1_route.advanced.multi_exit_discriminator = 50
    d1_route.advanced.origin = "egp"
    d1_route.communities.add(as_number=1, as_custom=2, type="manual_as_number")
    d1_route.as_path.as_set_mode = "include_as_set"
    d1_route.as_path.segments.add(as_numbers=[1112, 1113], type="as_seq")

    d2_eth = d2.ethernets.add(name="d2Eth", mac="00:00:02:02:02:02", mtu=1500)
    d2_eth.connection.port_name = p2.name
    d2_ipv4 = d2_eth.ipv4_addresses.add(
        name="p2d2ipv4",
        address="1.1.1.2",
        gateway="1.1.1.1",
        prefix=24,
    )

    d2_bgp = d2.bgp
    d2_bgp.router_id = "1.1.1.2"
    d2_bgp_if = d2_bgp.ipv4_interfaces.add(ipv4_name=d2_ipv4.name)
    d2_peer = d2_bgp_if.peers.add(
        name="BGP Peer 2",
        peer_address="1.1.1.1",
        as_number=2222,
        as_type="ebgp",
    )
    d2_route = d2_peer.v4_routes.add(
        name="p2d2peer1rrv4",
        next_hop_ipv4_address="1.1.1.2",
        next_hop_address_type="ipv4",
        next_hop_mode="manual",
    )
    d2_route.addresses.add(address="20.20.20.0", prefix=24, count=2, step=2)
    d2_route.advanced.multi_exit_discriminator = 40
    d2_route.advanced.origin = "egp"
    d2_route.communities.add(as_number=100, as_custom=2, type="manual_as_number")
    d2_route.as_path.as_set_mode = "include_as_set"
    d2_route.as_path.segments.add(as_numbers=[2223, 2224, 2225], type="as_seq")

    flow = cfg.flows.add(name=f"{p1.name} -> {p2.name}")
    flow.metrics.enable = True
    flow.duration.fixed_packets.packets = 1000
    flow.rate.pps = 500
    flow.tx_rx.device.tx_names = [d1_route.name]
    flow.tx_rx.device.rx_names = [d2_route.name]

    flow.packet.ethernet()
    flow.packet.ipv4()
    eth = flow.packet[0]
    ip = flow.packet[1]
    eth.src.value = d1_eth.mac
    eth.dst.value = "00:00:02:02:02:02"
    ip.src.value = "10.10.10.1"
    ip.dst.value = "20.20.20.1"

    return api, cfg, flow


def wait_for_bgp(api, timeout_seconds=10):
    req = api.metrics_request()
    req.bgpv4.peer_names = []
    deadline = time.time() + timeout_seconds
    logger.info("Waiting for BGP sessions to become established...")

    while True:
        metrics = api.get_metrics(req)
        all_up = True
        for metric in metrics.bgpv4_metrics:
            peer_name = getattr(metric, "name", getattr(metric, "peer_name", "unknown"))
            logger.info("BGP metric: peer=%s session_state=%s advertised=%s received=%s",
                        peer_name,
                        getattr(metric, "session_state", "unknown"),
                        getattr(metric, "routes_advertised", 0),
                        getattr(metric, "routes_received", 0))
            if metric.session_state == "down" or metric.routes_advertised != metric.routes_received:
                all_up = False
                break
        if all_up:
            logger.info("BGP sessions are established and routes are in sync.")
            return
        if time.time() >= deadline:
            raise RuntimeError("BGP session never reached expected state")
        logger.info("BGP not ready yet; polling again in %ss", POLL_INTERVAL_SECONDS)
        time.sleep(POLL_INTERVAL_SECONDS)


def wait_for_flow(api, flow_name: str, packet_count: int, timeout_seconds=10):
    req = api.metrics_request()
    req.flow.flow_names = [flow_name]
    deadline = time.time() + timeout_seconds
    logger.info("Waiting for traffic flow '%s' to complete (%s packets expected)...", flow_name, packet_count)

    while True:
        metrics = api.get_metrics(req)
        flow_metrics = list(metrics.flow_metrics)
        if not flow_metrics:
            if time.time() >= deadline:
                raise RuntimeError("Flow never reached expected completion state")
            logger.info("Flow metrics not yet available; polling again in %ss", POLL_INTERVAL_SECONDS)
            time.sleep(POLL_INTERVAL_SECONDS)
            continue

        flow_metric = flow_metrics[0]
        logger.info(
            "Flow metric: name=%s transmit=%s frames_rx=%s frames_tx=%s",
            getattr(flow_metric, "name", flow_name),
            getattr(flow_metric, "transmit", "unknown"),
            getattr(flow_metric, "frames_rx", 0),
            getattr(flow_metric, "frames_tx", 0),
        )
        if getattr(flow_metric, "transmit", "") == "stopped" and flow_metric.frames_rx == packet_count:
            logger.info("Traffic flow '%s' completed successfully with %s received packets.", flow_name, flow_metric.frames_rx)
            return
        if time.time() >= deadline:
            raise RuntimeError("Flow never reached expected completion state")
        logger.info("Flow still running; polling again in %ss", POLL_INTERVAL_SECONDS)
        time.sleep(POLL_INTERVAL_SECONDS)


def test_quickstart(port_a: str = "veth1", port_z: str = "veth2", location: str = "https://localhost:8443"):
    logger.info("Running QuickstartB2BCpDp with ports: %s <-> %s", port_a, port_z)
    logger.info("Creating OTG config and topology for location: %s", location)

    api, cfg, flow = build_config(port_a, port_z, location)
    logger.info("OTG configuration JSON:\n%s", cfg.serialize(encoding=cfg.JSON))

    logger.info("Applying configuration to OTG controller")
    api.set_config(cfg)

    cs = api.control_state()
    logger.info("Starting protocol layer on all configured devices")
    cs.protocol.all.state = cs.protocol.all.START
    api.set_control_state(cs)

    wait_for_bgp(api, timeout_seconds=10)

    cs = api.control_state()
    logger.info("Starting traffic flow transmission for flow '%s'", flow.name)
    cs.traffic.flow_transmit.state = cs.traffic.flow_transmit.START
    api.set_control_state(cs)

    wait_for_flow(api, flow.name, packet_count=1000, timeout_seconds=10)
    logger.info("Quickstart test completed successfully.")


def main():
    parser = argparse.ArgumentParser(description="Run the CP-DP B2B snappi example.")
    parser.add_argument("--port-a", default="eth1", help="Name of port A interface")
    parser.add_argument("--port-z", default="eth2", help="Name of port Z interface")
    parser.add_argument("--location", default="https://localhost:8443", help="OTG API endpoint URL")
    args = parser.parse_args()
    test_quickstart(args.port_a, args.port_z, args.location)


if __name__ == "__main__":
    main()

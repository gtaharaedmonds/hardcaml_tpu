use pnet::datalink::Channel::Ethernet;
use pnet::datalink::{self, NetworkInterface};
use pnet::packet::Packet;
use pnet::packet::ethernet::{EtherType, EthernetPacket, MutableEthernetPacket};
use pnet::util::MacAddr;

use std::env;
use std::str::FromStr;

const SERVER_MAC: &str = "00:0A:35:01:02:03";

fn main() {
    let interface_name = env::args().nth(1).unwrap();
    let message = env::args().nth(2).unwrap();

    let interfaces: Vec<NetworkInterface> = datalink::interfaces();
    let interface_names_match = |iface: &NetworkInterface| iface.name == interface_name;

    // Find the network interface with the provided name.
    let interface = interfaces
        .into_iter()
        .filter(interface_names_match)
        .next()
        .unwrap();

    // Create a new channel, dealing with layer 2 packets.
    let (mut tx, mut rx) = match datalink::channel(&interface, Default::default()) {
        Ok(Ethernet(tx, rx)) => (tx, rx),
        Ok(_) => panic!("Unhandled channel type"),
        Err(e) => panic!(
            "An error occurred when creating the datalink channel: {:?}",
            e
        ),
    };

    println!("Sending message...");

    let server_addr = MacAddr::from_str(SERVER_MAC).unwrap();
    tx.build_and_send(
        1,
        EthernetPacket::minimum_packet_size() + message.len(),
        &mut |new_packet| {
            let mut new_packet = MutableEthernetPacket::new(new_packet).unwrap();

            new_packet.set_source(interface.mac.unwrap());
            new_packet.set_destination(server_addr);

            new_packet.set_ethertype(EtherType(message.len() as u16));
            new_packet.set_payload(message.as_bytes());
        },
    );

    println!("Sent message!");
    println!("Waiting for echo...");

    let mut packet;
    loop {
        let echo = rx.next().unwrap();
        packet = EthernetPacket::new(echo).unwrap();

        if packet.get_source() == server_addr {
            break;
        }
    }

    println!(
        "Got echo! {:?}",
        core::str::from_utf8(packet.payload()).unwrap()
    );
}

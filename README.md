# UART Transceiver

## Overview
This project implements a full-duplex UART (Universal Asynchronous Receiver/Transmitter) in Verilog HDL, supporting serial transmission and reception of 8-bit data. The design includes a configurable baud-rate generator, an 8-bit UART transmitter, and a 16x-oversampling UART receiver, integrated under a top-level module. The design is functionally verified using dedicated Verilog testbenches.

## Features
- Full-duplex UART transmitter and receiver
- Configurable baud-rate generator (1x tick for TX, 16x oversampling tick for RX)
- 8-bit parallel-to-serial transmitter with start/stop bit framing
- 16x-oversampling receiver FSM (IDLE → START → DATA → STOP) for reliable mid-bit sampling
- Busy/ready status flags for TX and RX handshaking
- Top-level integration module combining transmitter, receiver, and baud generator
- Functional verification using self-checking Verilog testbenches

## Tools Used
- Verilog HDL
- Xilinx Vivado
- ModelSim (or your simulator)

## Author
**Pratiksha Upadhye**                                      

Electronics & Telecommunication Engineering Student | Aspiring RTL Design & Verification Engineer

GitHub: https://github.com/upadhyepratiiksha-dot

LinkedIn: https://linkedin.com/in/pratiksha-upadhye

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/12/2020 04:42:25 PM
// Design Name: 
// Module Name: iopin
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module iopin(
    input i,
    output o,
    input t,
    inout io
    );
    IOBUF iob (.O(o), .IO(io), .I(i), .T(t));
endmodule

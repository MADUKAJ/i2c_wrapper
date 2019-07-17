# I2C Wrapper
This project aims to facilitate i2c communication of FPGA with Si5397/96

The The Si5397 is a high-performance, jitter-attenuating clock multiplier. The internal register map consists of several pages with 
256 memory locations each.
12C Protocol can be used to write to those registers. I have used the I2C-Master Core developed by Richard Herveille and developed a 
wrapper including address and data mmemories inside it. The address and data memories are initiated by .coe files which contains the
register address and the data to be written to the relevant register. To test the nodel, I have used the I2C-Slave model beveloped by
Richard Herveille.

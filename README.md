# 32-bit Floating Point Unit (FPU) - Addition and Subtraction

A hardware implementation of a 32-bit IEEE 754 floating-point adder/subtractor written in SystemVerilog. This design supports standard floating-point operations including special cases (NaN, Infinity, Zero, Subnormal numbers).

## Features

- **IEEE 754 Single Precision** (32-bit) floating-point format
- **Addition and Subtraction** operations
- **Special Case Handling**:
  - NaN (Not a Number)
  - Infinity (±∞)
  - Zero (±0)
  - Subnormal numbers
- **Exception Flags**: Overflow, Underflow, Zero detection
- **Modular Design**: Separate modules for each operation stage
- **Synthesizable**: Ready for FPGA implementation (tested on Intel Quartus)

## Project Structure

```
32-bit-fpu/
├── 01_rtl/                     # RTL source files
│   ├── fpu_add_sub_top.sv      # Top-level module
│   ├── fpu_unpack_pretest.sv   # Input unpacking and preprocessing
│   ├── fpu_special_case.sv     # Special case detection
│   ├── fpu_swap_operands.sv    # Operand swapping logic
│   ├── fpu_exponent_subtractor.sv  # Exponent difference calculation
│   ├── fpu_align_shift_right.sv    # Mantissa alignment
│   ├── fpu_sign_computation.sv     # Sign bit computation
│   ├── fpu_sig_add_sub.sv      # Significand addition/subtraction
│   ├── fpu_normalization.sv    # Result normalization
│   ├── fpu_basic_lib.sv        # Basic functions library
│   └── fpu_wrapper.sv          # Wrapper module
├── 02_constraints/             # Timing constraints
│   └── fpu.sdc                 # Synopsys Design Constraints
├── 03_scripts/                 # Build and synthesis scripts
│   ├── fpu.tcl                 # Quartus TCL script
│   └── pin_assignment.tcl      # Pin assignment script
├── 04_tb/                      # Testbench files
│   ├── fpu_add_sub_tb.sv       # Main testbench
│   └── gpdk045_lib/            # Technology library
├── 05_reports/                 # Synthesis and timing reports
│   ├── critical_path.rpt.txt   # Critical path analysis
│   └── timing_lint.txt         # Timing check results
├── 06_docs/                    # Documentation and diagrams
├── fpu_add_sub_top.qpf         # Quartus project file
└── fpu_add_sub_top.qsf         # Quartus settings file
```

## Module Interface

### Top Module: `fpu_add_sub_top`

| Port Name      | Direction | Width  | Description                                      |
|----------------|-----------|--------|--------------------------------------------------|
| `i_a`          | Input     | 32-bit | First operand (IEEE 754 format)                  |
| `i_b`          | Input     | 32-bit | Second operand (IEEE 754 format)                 |
| `i_add_sub`    | Input     | 1-bit  | Operation select (0 = Addition, 1 = Subtraction) |
| `o_z`          | Output    | 32-bit | Result (IEEE 754 format)                         |
| `o_overflow`   | Output    | 1-bit  | Overflow flag                                    |
| `o_underflow`  | Output    | 1-bit  | Underflow flag                                   |
| `o_zero`       | Output    | 1-bit  | Zero result flag                                 |

### IEEE 754 Single Precision Format

```
| Sign (1 bit) | Exponent (8 bits) | Mantissa (23 bits) |
|--------------|-------------------|-------------------|
|     31       |     30-23         |      22-0         |
```

## Requirements

### Hardware Synthesis
- **Intel Quartus Prime** (tested with version 20.1+)
- **FPGA Board**: Cyclone, Arria, or Stratix series (optional for hardware testing)

### Simulation
- **ModelSim** or **QuestaSim**
- **Alternatively**: Any SystemVerilog-compatible simulator (VCS, Xcelium, Verilator)

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/32-bit-fpu.git
cd 32-bit-fpu
```

### 2. Simulation

Using ModelSim/QuestaSim:

```bash
# Create work library
vlib work

# Compile all RTL files
vlog 01_rtl/*.sv

# Compile testbench
vlog 04_tb/fpu_add_sub_tb.sv

# Run simulation
vsim -c fpu_add_sub_tb -do "run -all; quit"
```

### 3. Synthesis (Quartus)

```bash
# Open Quartus project
quartus_sh --project fpu_add_sub_top.qpf

# Run synthesis
quartus_sh --flow compile fpu_add_sub_top
```

Or use the TCL script:

```bash
quartus_sh -t 03_scripts/fpu.tcl
```

### 4. Run Testbench

The testbench (`04_tb/fpu_add_sub_tb.sv`) includes comprehensive test cases:
- Normal number addition/subtraction
- Special cases (NaN, Infinity, Zero)
- Corner cases (overflow, underflow)
- Subnormal number handling

Expected output shows pass/fail status for each test case.

## Design Overview

The FPU pipeline consists of the following stages:

1. **Unpack & Pretest**: Extract sign, exponent, and mantissa; detect special cases
2. **Special Case Handling**: Handle NaN, Infinity, Zero combinations
3. **Operand Swap**: Ensure larger magnitude operand is first
4. **Exponent Subtraction**: Calculate exponent difference
5. **Alignment**: Right-shift smaller mantissa to align with larger
6. **Sign Computation**: Determine result sign based on operation
7. **Significand Add/Sub**: Perform actual addition or subtraction
8. **Normalization**: Normalize result and adjust exponent
9. **Pack & Flag**: Assemble final IEEE 754 format and set exception flags

## Testing

The project includes extensive test vectors covering:
- ✅ Basic addition and subtraction
- ✅ Addition of positive and negative numbers
- ✅ Subtraction resulting in zero
- ✅ Overflow conditions
- ✅ Underflow conditions
- ✅ NaN propagation
- ✅ Infinity arithmetic
- ✅ Subnormal number handling
- ✅ Edge cases (min/max normal values)

## Synthesis Results

*Results may vary depending on target FPGA and optimization settings*

- **Target Device**: Cyclone II
- **Maximum Frequency**: 28.5 MHz
- **Logic Elements**: 871 LEs
- **Timing Constraint**: Refer to `02_constraints/fpu.sdc`

See `05_reports/` for detailed timing analysis.

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Authors

- **Group 3**
- Faculty of Electrical-Electronics Engineering
- Department of Electronics

## Acknowledgments

- IEEE 754 Standard for Floating-Point Arithmetic
- Course: Digital System Design and Verification
- Institution: Faculty of Electrical-Electronics Engineering, Department of Electronics

## References

- [IEEE 754-2008 Standard](https://ieeexplore.ieee.org/document/4610935)
- [Floating-Point Arithmetic](https://docs.oracle.com/cd/E19957-01/806-3568/ncg_goldberg.html)

## Contact

For questions or support, please open an issue on GitHub or contact [phongnguyens2468@gmail.com]

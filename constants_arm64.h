// Constants for ARM64 assembly fast paths

// Character constants
#define CHAR_0         $48    // '0'
#define CHAR_9         $57    // '9'
#define CHAR_DOT       $46    // '.'
#define CHAR_MINUS     $45    // '-'
#define CHAR_PLUS      $43    // '+'
#define CHAR_e         $101   // 'e'
#define CHAR_E         $69    // 'E'
#define CHAR_x         $120   // 'x'
#define CHAR_X         $88    // 'X'
#define CHAR_p         $112   // 'p'
#define CHAR_P         $80    // 'P'
#define CHAR_a         $97    // 'a'
#define CHAR_f         $102   // 'f'
#define CHAR_A         $65    // 'A'
#define CHAR_F         $70    // 'F'

// Numeric constants
#define TEN            $10
#define SIXTEEN        $16
#define NINETEEN       $19
#define MAX_EXP        $10000

// Bit masks
#define SIGN_BIT       $0x8000000000000000

// Exponent bias for float64
#define EXP_BIAS       $1023
#define EXP_BITS       $11
#define MANTISSA_BITS  $52
#define IMPLICIT_BIT   $0x0010000000000000


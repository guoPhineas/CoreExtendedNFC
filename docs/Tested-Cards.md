# Tested Cards

Real-card scans captured with the CENFC app and exported as `.cenfc` records on 2026-04-06.

## Summary

| Card Type                       |  Count |
| ------------------------------- | -----: |
| FeliCa Standard                 |      3 |
| ISO 15693 (generic)             |      5 |
| MIFARE DESFire EV1              |      1 |
| MIFARE DESFire (generic)        |      1 |
| MIFARE Ultralight EV1 (MF0UL11) |      2 |
| MIFARE Ultralight (generic)     |      2 |
| NFC Forum Type 4 Tag            |      3 |
| NTAG213                         |      3 |
| NTAG215                         |      2 |
| NTAG216                         |      2 |
| **Total**                       | **24** |

## Tested List

| Card Type                       | UID                       | Scan Date (UTC)     | Notes                                         |
| ------------------------------- | ------------------------- | ------------------- | --------------------------------------------- |
| FeliCa Standard                 | `01 2E 5C E8 07 94 21 77` | 2026-04-06 06:23:51 | `systemCode=88B4`                             |
| FeliCa Standard                 | `01 2E 5C E8 07 94 5C 89` | 2026-04-06 06:22:49 | `systemCode=88B4`                             |
| FeliCa Standard                 | `01 2E 61 10 96 8A 78 36` | 2026-04-06 06:24:25 | `systemCode=88B4`                             |
| ISO 15693 (generic)             | `E0 04 01 00 89 88 04 85` | 2026-04-06 06:22:14 | —                                             |
| ISO 15693 (generic)             | `E0 04 01 00 89 88 2E D1` | 2026-04-06 06:24:02 | —                                             |
| ISO 15693 (generic)             | `E0 04 01 50 B5 93 A7 CB` | 2026-04-06 06:23:46 | —                                             |
| ISO 15693 (generic)             | `E0 04 01 50 B5 94 4B 1D` | 2026-04-06 06:22:24 | —                                             |
| ISO 15693 (generic)             | `E0 04 01 53 0B 29 61 E0` | 2026-04-06 06:24:41 | —                                             |
| MIFARE DESFire EV1              | `04 5C 7B 9A 13 35 80`    | 2026-04-06 06:23:22 | DESFire `GET_VERSION` refined to EV1          |
| MIFARE DESFire (generic)        | `04 9B 1D 0A E2 12 90`    | 2026-04-06 06:23:41 | DESFire detected, no EV generation refinement |
| MIFARE Ultralight EV1 (MF0UL11) | `04 55 91 1A 93 13 91`    | 2026-04-06 06:22:56 | `GET_VERSION` refined                         |
| MIFARE Ultralight EV1 (MF0UL11) | `04 80 CA 2A 93 13 91`    | 2026-04-06 06:22:36 | `GET_VERSION` refined                         |
| MIFARE Ultralight (generic)     | `04 34 AD 7A 77 7A 80`    | 2026-04-06 06:22:45 | remained generic in scan export               |
| MIFARE Ultralight (generic)     | `04 F0 F2 7A 77 7A 80`    | 2026-04-06 06:23:55 | remained generic in scan export               |
| NFC Forum Type 4 Tag            | `04 23 32 EA 76 74 80`    | 2026-04-06 06:24:15 | `initialSelectedAID=D2760000850101`           |
| NFC Forum Type 4 Tag            | `54 FF 17 25`             | 2026-04-06 06:24:29 | `initialSelectedAID=D2760000850101`           |
| NFC Forum Type 4 Tag            | `E7 78 49 D6`             | 2026-04-06 06:24:34 | `initialSelectedAID=D2760000850101`           |
| NTAG213                         | `04 2E 52 AA 40 15 91`    | 2026-04-06 06:24:22 | `GET_VERSION` refined                         |
| NTAG213                         | `04 40 99 9A 35 70 81`    | 2026-04-06 06:22:53 | `GET_VERSION` refined                         |
| NTAG213                         | `04 8E 17 9A 35 70 80`    | 2026-04-06 06:22:27 | `GET_VERSION` refined                         |
| NTAG215                         | `04 AC 3E 42 5E 6A 80`    | 2026-04-06 06:23:35 | `GET_VERSION` refined                         |
| NTAG215                         | `04 FC C0 42 5E 6A 80`    | 2026-04-06 06:22:32 | `GET_VERSION` refined                         |
| NTAG216                         | `04 3F 66 A2 75 14 90`    | 2026-04-06 06:24:09 | `GET_VERSION` refined                         |
| NTAG216                         | `04 CF 0E A2 75 14 90`    | 2026-04-06 06:22:41 | `GET_VERSION` refined                         |

## Notes

- This list is derived from exported `.cenfc` scan records, not synthetic fixtures.
- “generic” means the scan was identified to the family level but did not refine to a more specific chip variant in the saved export.
- NFC Forum Type 4 entries were identified through standard NDEF application probing.

# Masked_Gaussian_Sampler
Hello! These are all the required verilog files which you will require to run a masked gaussian sampler for Falcon scheme. Please note that our sampler (CDT) is only a close approximation for demo purposes. Masking is implemented to mitigate power analysis based side-channel attacks.

I would like to thank our proctor, Mrs. Ashwini V, for guiding us to successfully complete this project.
The team which made these codes and testbench: Bhishma P. S, Chaitanya Lahari D, B Balaaditya and Steephen Raj K.

Here's a note on how to view the output correctly.

Top module -> top_module.v, underneath which set bottom modules of dbrg_system.v and masked_gau_multiple_sigma.v

Underneath the dbrg_system.v, set bottom modules trng_system.v and drbg.v

Underneath trng_system.v, set bottom modules trng.v and seeder.v
Under drbg.v set bottom module keccak_core.v

Add the top_testbench to simulation sources and that's it!

Enjoy! Thank you for viewing!
Regards,
Bhishma

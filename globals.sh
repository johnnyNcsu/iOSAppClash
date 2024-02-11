# !!! IMPORTANT: UNIQUE_ID_FIELD_LEN, HASH_STING_LEN, & IOS_NAME_LEN MUST BE SET TO
# THE SAME VALUES AS THEIR COUNTERPARTS USED THROUGHOUT THIS CODEBASE.

# =============================================================================================
# UNIQUE_ID_FIELD_LEN is an arbitrary number of characters that we designate as the unique ID
# assigned to a participating device. This ID is created by taking the first N characters
# (where N is the numerical value assigned to the UNIQUE_ID_FIELD_LEN) of the SHA256 hash
# of the UDID (unique device ID) for each device. Setting this value to fewer than 6 may
# result in ID collisions as the number of participating devices grows. For groups less than
# 100, the probability of a collision is a 3 in 10,000 chance. However, for groups of 1000,
# the probability of a collision is 3%! In other words, we should expect approximately 30
# collisions if we use 6 character IDs with 1000 participating devices. For this reason,
# the UNIQUE_ID_FIELD_LEN with value should be increased to 10 characters for safety with
# large groups. These scripts can support up to 20 character IDs without modification and
# larger with minor changes.
#
# The unique ID is used in the key and upload filenames to guarantee each a unique name and
# it is also used to create the histogram bar graph identifying when a participating device
# has the same app installed as the local device. For this reason, it is desireable to make
# this field as short as possible to prevent the histogram bars from growing excessively large
# but we must also keep in mind that shorter IDs are more likely to incur a collision.
#
# Recommended UNIQUE_ID_FIELD_LEN min=6; max=20
#

UNIQUE_ID_FIELD_LEN=6

# HASH_STRING_LEN is the length of the string produced by the hash algorithm used to hash
# our app names. In this case, we use SHA256 which produces 64 character hashes.

HASH_STRING_LEN=64

# IOS_NAME_LEN is Apple's maximum length for an app name on iOS.

IOS_NAME_LEN=30
# =============================================================================================

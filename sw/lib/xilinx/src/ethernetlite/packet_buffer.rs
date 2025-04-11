use core::fmt;

use heapless::Vec;

use super::MacAddr;

unsafe fn aligned_volatile_copy<T>(src: &T, dest: &mut T) {
    unsafe {
        assert!(align_of::<T>() >= size_of::<u32>());
        assert!(size_of::<u32>() % 4 == 0);

        let src = core::slice::from_raw_parts(src as *const T as *const u8, size_of::<T>());
        let dest = core::slice::from_raw_parts_mut(
            dest as *mut T as *mut u32,
            size_of::<T>() / size_of::<u32>(),
        );

        for (i, chunk) in src.chunks(size_of::<u32>()).enumerate() {
            let word_bytes = if chunk.len() < size_of::<u32>() {
                let mut word_bytes = [0; size_of::<u32>()];
                word_bytes[..chunk.len()].copy_from_slice(chunk);
                word_bytes
            } else {
                chunk.try_into().unwrap()
            };

            core::ptr::write_volatile(
                core::ptr::addr_of_mut!(dest[i]),
                u32::from_le_bytes(word_bytes),
            );
        }
    }
}

pub const HEADER_SIZE: usize = 14;
pub const MAX_DATA_SIZE: usize = 200;

#[repr(C, align(4))]
pub struct PacketBuffer {
    pub dest_addr: MacAddr,
    pub src_addr: MacAddr,
    len: u16,
    data: [u8; MAX_DATA_SIZE],
}

static_assertions::assert_eq_size!(PacketBuffer, [u8; MAX_DATA_SIZE + HEADER_SIZE + 2]); // 2 is for alignment
static_assertions::assert_eq_align!(PacketBuffer, u32);

impl PacketBuffer {
    pub const UNINIT: Self = Self {
        dest_addr: MacAddr([0; 6]),
        src_addr: MacAddr([0; 6]),
        len: 0,
        data: [0; MAX_DATA_SIZE],
    };

    pub fn new(dest_addr: MacAddr, src_addr: MacAddr, data: Vec<u8, MAX_DATA_SIZE>) -> Self {
        let mut buffer = Self {
            dest_addr,
            src_addr,
            len: (data.len() as u16).to_be(),
            data: [0; MAX_DATA_SIZE],
        };
        buffer.data[..data.len()].copy_from_slice(data.as_slice());
        buffer
    }

    pub fn write_aligned(&mut self, other: &PacketBuffer) {
        unsafe { aligned_volatile_copy(other, self) };
    }

    pub fn read_aligned(&mut self) -> Self {
        let mut buffer = Self::UNINIT;
        unsafe { aligned_volatile_copy(self, &mut buffer) };
        buffer
    }

    // Be careful about using these, the packet needs to be allocated in DMEM, and not in the
    // ethernet peripheral itself, since they don't read entire words.
    pub fn data_len(&self) -> usize {
        self.len.swap_bytes() as usize
    }

    pub fn packet_len(&self) -> usize {
        HEADER_SIZE + self.data_len()
    }

    pub fn data(&self) -> Vec<u8, MAX_DATA_SIZE> {
        Vec::from_slice(&self.data[..self.data_len()]).unwrap()
    }

    pub fn bytes(&self) -> &[u8] {
        unsafe {
            core::slice::from_raw_parts(
                self as *const PacketBuffer as *const u8,
                size_of::<PacketBuffer>(),
            )
        }
    }
}

impl fmt::Debug for PacketBuffer {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("PacketBuffer")
            .field("dest_addr", &self.dest_addr)
            .field("src_addr", &self.src_addr)
            .field("data", &self.data())
            .finish()
    }
}

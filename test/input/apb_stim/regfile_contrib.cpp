#include "regfile_contrib.h"

/* regfile_dev */
void regfile_dev::rfdev_write_sequence (unsigned int length, rf_addr_t addr[], rf_data_t value[], rf_data_t mask[], rf_data_t unused_mask[])
{
    for (unsigned int i = 0; i < length; i++) {
        rfdev_write (addr[i], value[i], mask[i], unused_mask[i]);
    }
}

regfile_dev::~regfile_dev()
{}

/* regfile_dev_simple */
void regfile_dev_simple::rfdev_write (rf_addr_t addr, rf_data_t value, rf_data_t mask, rf_data_t unused_mask)
{
    rf_data_t keep_mask = ~(mask | unused_mask);

    if (keep_mask == 0) {
        rfdev_write_simple (addr, value);
    } else {
        rf_data_t tdata = rfdev_read (addr);

        tdata &= ~mask;
        tdata |= (value & mask);

        rfdev_write_simple (addr, tdata);
    }
}

regfile_dev_simple::~regfile_dev_simple()
{}

/* regfile_dev_subword */
void regfile_dev_subword::rfdev_write (rf_addr_t addr, rf_data_t value, rf_data_t mask, rf_data_t unused_mask)
{
    unsigned int nbytes = sizeof (rf_data_t);

    rf_data_t keep_mask = ~(mask | unused_mask);

    for (unsigned int bytesperword = nbytes; bytesperword > 0; bytesperword >>= 2) {
        rf_data_t word_mask = (1 << (bytesperword * 8)) - 1;

        for (unsigned int i = 0; i < nbytes / bytesperword; i++) {
            rf_data_t i_word_mask = word_mask << i;

            if (((keep_mask & i_word_mask) == 0) && ((mask & (~i_word_mask)) == 0)) {
                unsigned int byte_offset = i * bytesperword;
                unsigned int byte_size   = bytesperword;

                rfdev_write_subword (addr + byte_offset, value, byte_size);
                return;
            }
        }
    }

    /* no success */
    rf_data_t tdata = rfdev_read (addr);

    tdata &= ~mask;
    tdata |= (value & mask);

    rfdev_write_subword (addr, tdata, nbytes);
}

regfile_dev_subword::~regfile_dev_subword()
{}

/* regfile_dev_bitcache */
regfile_dev_bitcache::regfile_dev_bitcache (regfile_dev &main) :
    main_dev (main), cache_enabled (false)
{
    cache.valid = false;
}

rf_data_t regfile_dev_bitcache::rfdev_read (rf_addr_t addr)
{
    cache_flush ();
    return main_dev.rfdev_read (addr);
}

void regfile_dev_bitcache::rfdev_write (rf_addr_t addr, rf_data_t value, rf_data_t mask, rf_data_t unused_mask)
{
    if (!cache_enabled) {
        main_dev.rfdev_write (addr, value, mask, unused_mask);
        return;
    }

    if (cache.valid) {
        if ((cache.addr == addr) && (cache.unused_mask == unused_mask) && ((cache.mask & mask) == 0)) {
            cache.mask |= mask;

            /* update cache */
            rf_data_t tempval = cache.value;
            tempval    &= (~mask);
            tempval    |= (value & mask);
            cache.value = tempval;
        } else {
            cache_flush ();
            /* cache.valid -> false */
        }
    }

    if (!cache.valid) {
        /* set cache */
        cache.addr        = addr;
        cache.value       = value;
        cache.mask        = mask;
        cache.unused_mask = unused_mask;
        cache.valid       = true;
        return;
    }
}

void regfile_dev_bitcache::cache_enable ()
{
    cache_enabled = true;
}

void regfile_dev_bitcache::cache_disable ()
{
    cache_flush ();
    cache_enabled = false;
}

void regfile_dev_bitcache::cache_flush ()
{
    if (!cache_enabled) return;
    if (!cache.valid) return;

    main_dev.rfdev_write (cache.addr, cache.value, cache.mask, cache.unused_mask);

    cache.valid = false;
}

/* regfile_dev_wordcache */
regfile_dev_wordcache::regfile_dev_wordcache (regfile_dev &main, unsigned int maxseq) :
    main_dev (main), seqlen_max (maxseq), cache_enabled (false)
{
    seqlen = 0;

    addr_list        = new rf_addr_t[maxseq];
    value_list       = new rf_data_t[maxseq];
    mask_list        = new rf_data_t[maxseq];
    unused_mask_list = new rf_data_t[maxseq];
}

regfile_dev_wordcache::~regfile_dev_wordcache ()
{
    delete[] addr_list;
    delete[] value_list;
    delete[] mask_list;
    delete[] unused_mask_list;
}

rf_data_t regfile_dev_wordcache::rfdev_read (rf_addr_t addr)
{
    cache_flush ();
    return main_dev.rfdev_read (addr);
}

void regfile_dev_wordcache::rfdev_write (rf_addr_t addr, rf_data_t value, rf_data_t mask, rf_data_t unused_mask)
{
    if (!cache_enabled) {
        main_dev.rfdev_write (addr, value, mask, unused_mask);
        return;
    }

    addr_list[seqlen]        = addr;
    value_list[seqlen]       = value;
    mask_list[seqlen]        = mask;
    unused_mask_list[seqlen] = unused_mask;

    seqlen++;
    if (seqlen >= seqlen_max) cache_flush ();
}

void regfile_dev_wordcache::cache_enable ()
{
    cache_enabled = true;
}

void regfile_dev_wordcache::cache_disable ()
{
    cache_flush ();
    cache_enabled = false;
}

void regfile_dev_wordcache::cache_flush ()
{
    if (!cache_enabled) return;
    if (seqlen <= 0) return;

    main_dev.rfdev_write_sequence (seqlen, addr_list, value_list, mask_list, unused_mask_list);

    seqlen = 0;
}

/* regfile_t */
regfile_t::regfile_t (regfile_dev &dev, rf_addr_t base_addr) :
    _dev (dev), _base_addr (base_addr)
{}

rf_data_t regfile_t::_read (rf_addr_t addr)
{
    return _dev.rfdev_read (_base_addr + addr);
}

void regfile_t::_write (rf_addr_t addr, rf_data_t value, rf_data_t mask, rf_data_t unused_mask)
{
    _dev.rfdev_write (_base_addr + addr, value, mask, unused_mask);
}

rf_addr_t regfile_t::_get_addr ()
{
    return _base_addr;
}

/* _entry_t */
_entry_t::_entry_t(regfile_t &rf, rf_addr_t addr, rf_data_t unused_mask) :
    _m_rf (rf), _m_addr (addr), _m_unused_mask (unused_mask)
{}

void _entry_t::_entry_t_write (rf_data_t value)
{
    _m_rf._write (_m_addr, value, 0xffffffff, _m_unused_mask);
}

rf_data_t _entry_t::_entry_t_read ()
{
    rf_data_t value = _m_rf._read (_m_addr);

    return value;
}

rf_addr_t _entry_t::_entry_t_addr ()
{
    return _m_rf._get_addr () + _m_addr;
}

_entry_t& _entry_t::operator= (rf_data_t value)
{
    _entry_t_write (value);
    return *this;
}

_entry_t::operator rf_data_t ()
{
    return _entry_t_read  ();
}

rf_data_t *_entry_t::operator& ()
{
    return (rf_data_t *)(uintptr_t)_entry_t_addr ();
}

/* _reg_t */
void _reg_t::_reg_t_write (rf_data_t value)
{
    value <<= _m_lsb;
    value  &= _m_mask;
    _m_entry._m_rf._write (_m_entry._m_addr, value, _m_mask, _m_entry._m_unused_mask);
}
rf_data_t _reg_t::_reg_t_read ()
{
    rf_data_t value = _m_entry._m_rf._read (_m_entry._m_addr);

    value  &= _m_mask;
    value >>= _m_lsb;
    return value;
}

_reg_t::_reg_t (_entry_t &entry, unsigned int lsb, unsigned int msb) :
    _m_entry (entry), _m_lsb (lsb)
{
    /*
     * (1 << (msb+1)) does not work for msb = 31 and data type uint32_t:
     * result would/might/can be (1 << 32) --> (1 << 0) --> 1
     * workaround: (2 << msb)
     */
    _m_mask = (2 << msb) - (1 << lsb);
}

/* _reg_ro_t */
_reg_ro_t::_reg_ro_t (_entry_t &entry, unsigned int lsb, unsigned int msb) :
    _reg_t (entry, lsb, msb)
{}

_reg_ro_t::operator rf_data_t ()
{
    return _reg_t_read ();
}

/* _reg_rw_t */
_reg_rw_t::_reg_rw_t (_entry_t &entry, unsigned int lsb, unsigned int msb) :
    _reg_t (entry, lsb, msb)
{}

_reg_rw_t& _reg_rw_t::operator= (rf_data_t value)
{
    _reg_t_write (value);
    return *this;
}

_reg_rw_t::operator rf_data_t ()
{
    return _reg_t_read ();
}


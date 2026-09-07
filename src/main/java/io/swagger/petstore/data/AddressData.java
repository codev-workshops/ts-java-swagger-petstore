/**
 * Copyright 2018 SmartBear Software
 * <p>
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * <p>
 * http://www.apache.org/licenses/LICENSE-2.0
 * <p>
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package io.swagger.petstore.data;

import io.swagger.petstore.model.Address;

import java.util.ArrayList;
import java.util.List;

public class AddressData {
    private static List<Address> addresses = new ArrayList<>();

    static {
        addresses.add(createAddress(1, "437 Lytton", "Palo Alto", "CA", "94301", "USA"));
        addresses.add(createAddress(2, "1 Infinite Loop", "Cupertino", "CA", "95014", "USA"));
    }

    public Address getAddressById(final long addressId) {
        for (final Address address : addresses) {
            if (address.getId() == addressId) {
                return address;
            }
        }
        return null;
    }

    public void addAddress(final Address address) {
        if (addresses.size() > 0) {
            addresses.removeIf(addressN -> addressN.getId() == address.getId());
        }
        addresses.add(address);
    }

    public void deleteAddressById(final Long addressId) {
        addresses.removeIf(address -> address.getId() == addressId);
    }

    public static Address createAddress(final long id, final String street, final String city, final String state,
                                        final String zipCode, final String country) {
        final Address address = new Address();
        address.setId(id);
        address.setStreet(street);
        address.setCity(city);
        address.setState(state);
        address.setZipCode(zipCode);
        address.setCountry(country);
        return address;
    }
}
